defmodule Kantele.Combat.Skills.Performs.LuoyanJian.Luo do
  @moduledoc """
  perform「一剑落九雁」（对照 `kungfu/skill/luoyan-jian/luo.c`）

  门槛（按 .c 顺序）：已学此招 → 战斗中的对手 → 持剑 → 回风落雁剑>=150 →
  激发 sword 为回风落雁剑 → 真气>=400 → 目标存活。
  起手广播后攻击方扣 200 真气；以 `ap = sword 等级`、`dp = 目标 dodge` 判定，
  命中则 `count = 回风落雁剑/40` 并广播「连连后退…」，否则 `count = 0` 且广播
  「只得小心应付。」；随后连出 9 击（每击 1/3 概率令未忙乱的目标忙乱 1 回合）；
  收招忙乱 `1 + random(9)`。

  差异（TODO(migrate)）：
  - `ap`/`dp` 判定及其两条分支文案在目标侧结算（目标 dodge 只在自身进程可得），
    故 `message_combatd` 的两条文案由目标侧广播；
  - LPC 的 9 次 `COMBAT_D->do_attack`（完整 AP/DP/招架/伤害管线）折算为每击
    `level/15` 基础伤害 + 命中判定 `ap/2 + count + random(ap)` vs 目标 dodge
    （同 `duanjia_sword/jue.ex`）；`do_attack` 无独立命中/失手文案，由引擎动作表
    生成，故本文件不再自行发布逐击结果文案；
  - `me->add_temp("apply/attack", ±count)` 的临时加成折入目标侧逐击命中判定
    （攻击方本地 temp 对远程结算无意义），收招的 `-count` 不再重复落账；
  - `message_sort/3`（按感知排序）降级为房间广播；
  - 起手文案 `"…手中" + weapon->name() + "青光荡漾…"` 按 `.c` 原样拆为三段；
  - `living(target)` 门槛在攻击方无 meta 可查，由目标侧 `combat/perform-incoming`
    的死亡检查兜底（同 `chongyang_shenzhang/lian.ex`）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine

  @perform_id "luoyan-jian/luo"
  @move_name "「一剑落九雁」"

  # LPC: for (i = 0; i < 9; i++) COMBAT_D->do_attack(me, target, weapon, 0);
  @strikes 9

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "luoyan-jian")
    ap = Stats.skill(stats, "sword")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(character),
         :ok <- check_mapped(character),
         :ok <- check_resources(character),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          ap: ap,
          level: lvl,
          skill: lvl,
          strikes: @strikes,
          rng: rng
        }
      })

      apply_effect(conn, character, target, weapon_name(combat), rng)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id),
      do: :ok,
      else: {:error, "你所使用的外功中没有这种功能。\n"}
  end

  # LPC: if (! target) target = offensive_target(me);
  #      if (! target || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon"))
  #         || (string)weapon->query("skill_type") != "sword")
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "sword" do
      :ok
    else
      {:error, "你所使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if ((int)me->query_skill("luoyan-jian", 1) < 150)
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "luoyan-jian") < 150 do
      {:error, "你的回风落雁剑不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("sword") != "luoyan-jian")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "sword") == "luoyan-jian" do
      :ok
    else
      {:error, "你没有激发回风落雁剑法，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query("neili") < 400)
  defp check_resources(character) do
    if character.meta.vitals.neili < 400 do
      {:error, "你目前的真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (! living(target)) return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 敌人列表只存引用快照（%{id,pid,name,room_id}）时无 meta 可查，此时恒判存活，
  # 由目标侧 combat/perform-incoming 的死亡检查兜底。
  defp check_target_alive(target) do
    if not dead?(target) do
      :ok
    else
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_effect(conn, character, target, wep_name, rng) do
    # LPC: msg = HIW "\n$N…施出衡山派绝学「" HIR "一剑落九雁" HIW "」，手中"
    #            + weapon->name() + HIW "青光荡漾。…剑气笼罩$n" HIW "四方。" NOR;
    #      message_sort(msg, me, target);   me->add("neili", -200);
    #      … 9 击 …   me->start_busy(1 + random(9));
    # 攻击/目标分处两进程，起手文案在攻击方发布；9 击与两条分支文案在目标侧结算。
    vitals = character.meta.vitals
    vitals = %{vitals | neili: max(vitals.neili - 200, 0)}
    combat = Combat.start_busy(character.meta.combat, 1 + Engine.rand(rng, 9))
    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    conn =
      Broadcast.publish(
        conn,
        "\n$N蓦的一声清啸，施出衡山派绝学#{@move_name}，手中" <>
          wep_name <>
          "青光荡漾。霎时间回风落雁剑剑招连绵涌出，有如神助，剑气笼罩$n四方。\n",
        n1: character.name,
        n2: target.name
      )

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp weapon_name(combat) do
    case Combat.weapon(combat) do
      nil -> nil
      weapon -> Map.get(weapon, :name)
    end
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    # .c 的 !living(target) 在攻击方无 meta 可查，由此处死亡检查兜底。
    if character.meta.combat.dead do
      conn
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    level = max(Map.get(data, :level, 0), 1)
    strikes = Map.get(data, :strikes, @strikes)
    dodge = Stats.skill(character.meta.stats, "dodge")
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (ap / 2 + random(ap) > dp) { msg = "…连连后退，狼狈不已。\n";
    #            count = me->query_skill("luoyan-jian") / 40; }
    #      else { msg = "…只得小心应付。\n"; count = 0; }
    #      message_combatd(msg, me, target);
    {conn, count} =
      if div(ap, 2) + Engine.rand(rng, ap) > dodge do
        {Broadcast.publish(
           conn,
           "$n见$P剑势汹涌，寒意顿生，竟被逼得连连后退，狼狈不已。\n",
           bindings
         ), div(level, 40)}
      else
        {Broadcast.publish(
           conn,
           "$n见$N这几剑来势迅猛无比，毫无破绽，只得小心应付。\n",
           bindings
         ), 0}
      end

    per_hit = max(div(level, 15), 1)

    # LPC: for (i = 0; i < 9; i++) { if (! me->is_fighting(target)) break;
    #            if (random(3) == 1 && ! target->is_busy()) target->start_busy(1);
    #            COMBAT_D->do_attack(me, target, weapon, 0); }
    # 折算：每击 level/15 基础伤害 + 命中判定（ap/2 + count + random(ap) vs dodge）。
    {combat, damage} =
      Enum.reduce(1..strikes, {character.meta.combat, 0}, fn _, {combat_acc, damage_acc} ->
        combat_acc =
          if Engine.rand(rng, 3) == 1 and not Combat.busy?(combat_acc) do
            Combat.start_busy(combat_acc, 1)
          else
            combat_acc
          end

        if div(ap, 2) + count + Engine.rand(rng, ap) > dodge do
          {combat_acc, damage_acc + per_hit + Engine.rand(rng, per_hit)}
        else
          {combat_acc, damage_acc}
        end
      end)

    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, damage)
      |> Vitals.wound(:qi, div(damage, 3))

    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    put_character(conn, character)
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define LUO "「" HIR "一剑落九雁" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     object weapon;
  #     string msg;
  #     int ap, dp;
  #         int i, count;
  # 
  #         if (userp(me) && ! me->query("can_perform/luoyan-jian/luo"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (! target) target = offensive_target(me);
  # 
  #     if (! target || ! me->is_fighting(target))
  #                 return notify_fail(LUO "只能对战斗中的对手使用。\n");
  # 
  #     if (! objectp(weapon = me->query_temp("weapon"))
  #            || (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你所使用的武器不对，难以施展" LUO "。\n");
  # 
  #     if ((int)me->query_skill("luoyan-jian", 1) < 150)
  #         return notify_fail("你的回风落雁剑不够娴熟，难以施展" LUO "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "luoyan-jian")
  #                 return notify_fail("你没有激发回风落雁剑法，难以施展" LUO "。\n");
  # 
  #     if (me->query("neili") < 400)
  #         return notify_fail("你目前的真气不够，难以施展" LUO "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIW "\n$N" HIW "蓦的一声清啸，施出衡山派绝学「" HIR "一剑落九雁"
  #               HIW "」，手中" + weapon->name() + HIW "青光荡漾。霎时间回风"
  #               "落雁剑剑招连绵涌出，有如神助，剑气笼罩$n" HIW "四方。" NOR;
  # 
  #         message_sort(msg, me, target);
  # 
  #     ap = me->query_skill("sword");
  #     dp = target->query_skill("dodge");
  # 
  #     if (ap / 2 + random(ap) > dp)
  #     {
  #         msg = HIY "$n" HIY "见$P" HIY "剑势汹涌，寒意顿生，竟"
  #                       "被逼得连连后退，狼狈不已。\n" NOR;
  #                 count = me->query_skill("luoyan-jian") / 40;
  #         } else
  #         {
  #                 msg = HIC "$n" HIC "见$N" HIC "这几剑来势迅猛无比，毫"
  #                       "无破绽，只得小心应付。\n" NOR;
  #                 count = 0;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         me->add("neili", -200);
  #         me->add_temp("apply/attack", count);
  # 
  #         for (i = 0; i < 9; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  # 
  #                 if (random(3) == 1 && ! target->is_busy())
  #                         target->start_busy(1);
  # 
  #                 COMBAT_D->do_attack(me, target, weapon, 0);
  #         }
  # 
  #         me->add_temp("apply/attack", -count);
  #         me->start_busy(1 + random(9));
  #         return 1;
  # }
end
