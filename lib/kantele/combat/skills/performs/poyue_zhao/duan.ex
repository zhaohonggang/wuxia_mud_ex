defmodule Kantele.Combat.Skills.Performs.PoyueZhao.Duan do
  @moduledoc """
  perform「断脉破岳」（对照 `kungfu/skill/poyue-zhao/duan.c`）

  门槛（按 .c 顺序）：已学此招 → 战斗中的对手 → 空手
  （`query_temp("weapon")`）→ 破岳神爪>=80 → 激发 claw 为破岳神爪 →
  准备 claw 为破岳神爪 → **未把 cuff 准备为镇狱拳法**（互背，仅玩家）→
  真气>=100 → 目标存活。
  起手广播后无条件扣 50 真气，随后连出 4 次普通攻击
  （`.c` 的 `COMBAT_D->do_attack`），收招忙乱 `1 + random(4)`。

  差异（TODO(migrate)）：
  - `.c` 的 4 次 `do_attack`（完整 AP/DP/招架/伤害管线）折算为每击
    `level/15 + count` 基础伤害 + 命中判定（`ap/2 + count + random(ap)` vs
    目标 dodge，同 `pobei_tui/kai.ex` 先例）；`do_attack` 无独立命中/失手
    文案，由引擎动作表生成，故本文件不再自行发布逐击结果文案；
  - `me->start_busy(1 + random(4))` 位于 4 击之后，而 E 侧起手效果与目标侧
    连击是两个异步事件，故收敛在攻击方 apply_effect 中统一结算；
  - 「不谊和镇狱拳法互背」门槛（`userp(me)` + 准备的 cuff 为镇狱拳法）按
    `.c` 保留；框架无 userp 概念，恒按已学此招的用户路径处理；
  - `.c` 的错别字「不谊和」逐字保留；
  - `living(target)` 门槛在攻击方无 meta 可查，由目标侧
    `combat/perform-incoming` 的死亡检查兜底。
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

  @perform_id "poyue-zhao/duan"
  @move_name "「断脉破岳」"

  # LPC: for (i = 0; i < 4; i++) COMBAT_D->do_attack(me, target, 0, 0);
  @strikes 4

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1

    # LPC: me->query_skill("claw")（命中判定 ap 的基础项）
    ap = Stats.skill(stats, "claw")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(character),
         :ok <- check_prepared(character),
         :ok <- check_cuff_backup(character),
         :ok <- check_resources(character),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          ap: ap,
          strikes: @strikes,
          rng: rng
        }
      })

      apply_effect(conn, character, rng)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (userp(me) && ! me->query("can_perform/poyue-zhao/duan"))
  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target) target = offensive_target(me);
  #      if (! target || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (objectp(me->query_temp("weapon")))
  #      return notify_fail(DUAN "只能空手施展。\n");
  defp check_weapon(combat) do
    if Combat.weapon(combat) == nil do
      :ok
    else
      {:error, "#{@move_name}只能空手施展。\n"}
    end
  end

  # LPC: if ((int)me->query_skill("poyue-zhao", 1) < 80)
  #      if (me->query_skill_mapped("claw") != "poyue-zhao")
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "poyue-zhao") < 80 ->
        {:error, "你破岳神爪不够娴熟，难以施展#{@move_name}。\n"}

      Stats.mapped(stats, "claw") != "poyue-zhao" ->
        {:error, "你没有激发破岳神爪，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query_skill_prepared("claw") != "poyue-zhao")
  #              return notify_fail("你没有准备破岳神爪，难以施展" DUAN "。\n");
  # LPC 的 query_skill_prepared 返回技能名；框架 prepared_perform 返回绝招 ID，
  # 故按前缀比对（同其他 prepared 门槛）。
  defp check_prepared(character) do
    stats = character.meta.stats

    prepared_claw = Stats.prepared_perform(stats, "claw")

    if prepared_claw == nil or hd(String.split(prepared_claw, "/")) != "poyue-zhao" do
      {:error, "你没有准备破岳神爪，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: // 至于NPC么…这个…还是用互背的好，互背时把CLAW提前就行了。
  #      if (userp(me) && me->query_skill_prepared("cuff") == "zhenyu-quan")
  #              return notify_fail("施展" DUAN "时破岳神爪不谊和镇狱拳法互背。\n");
  # LPC 的 query_skill_prepared 返回技能名；框架 prepared_perform 返回绝招 ID，
  # 故按前缀比对；`userp(me)` 框界无对应概念，恒按用户路径处理。
  defp check_cuff_backup(character) do
    prepared = Stats.prepared_perform(character.meta.stats, "cuff")

    if prepared != nil and hd(String.split(prepared, "/")) == "zhenyu-quan" do
      {:error, "施展#{@move_name}时破岳神爪不谊和镇狱拳法互背。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 100)
  defp check_resources(character) do
    if character.meta.vitals.neili < 100 do
      {:error, "你现在真气不足，难以施展#{@move_name}。\n"}
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

  # LPC: msg = HIY "霎时间只见$N" HIY "身形一展，双爪疾攻而上，爪影笼罩$n"
  #            HIY "全身各处要穴。\n" NOR;
  #      message_combatd(msg, me, target);
  #      me->add("neili", -50);
  #      … 4 击（目标侧结算）…
  #      me->start_busy(1 + random(4));
  defp apply_effect(conn, character, rng) do
    conn =
      Broadcast.publish(
        conn,
        "霎时间只见$N身形一展，双爪疾攻而上，爪影笼罩$n全身各处要穴。\n",
        n1: character.name
      )

    # LPC: me->add("neili", -50);
    vitals = %{character.meta.vitals | neili: max(character.meta.vitals.neili - 50, 0)}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    # LPC: me->start_busy(1 + random(4));
    combat = Combat.start_busy(character.meta.combat, 1 + Engine.rand(rng, 4))
    character = %{character | meta: %{character.meta | combat: combat}}

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    # .c 的 !living(target) 在攻击方无 meta 可查，由此处死亡检查兜底。
    if character.meta.combat.dead do
      conn
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, _attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    strikes = Map.get(data, :strikes, @strikes)
    level = Stats.skill(character.meta.stats, "poyue-zhao")
    dodge = Stats.skill(character.meta.stats, "dodge")

    # LPC: for (i = 0; i < 4; i++) { if (! me->is_fighting(target)) break;
    #            COMBAT_D->do_attack(me, target, 0, 0); }
    # 折算：每击 level/15 基础伤害 + 命中判定（ap/2 + random(ap) vs dodge）。
    {combat, damage} =
      Enum.reduce(1..strikes, {character.meta.combat, 0}, fn _, {combat_acc, damage_acc} ->
        if div(ap, 2) + Engine.rand(rng, ap) > dodge do
          per_hit = max(div(level, 15), 1)
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
  # #define DUAN "「" HIY "断脉破岳" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         string msg;
  #         int i;
  # 
  #         if (userp(me) && ! me->query("can_perform/poyue-zhao/duan"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(DUAN "只能对战斗中的对手使用。\n");
  # 
  #         if (objectp(me->query_temp("weapon")))
  #                 return notify_fail(DUAN "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("poyue-zhao", 1) < 80)
  #                 return notify_fail("你破岳神爪不够娴熟，难以施展" DUAN "。\n");
  # 
  #         if (me->query_skill_mapped("claw") != "poyue-zhao")
  #                 return notify_fail("你没有激发破岳神爪，难以施展" DUAN "。\n");
  # 
  #         if (me->query_skill_prepared("claw") != "poyue-zhao")
  #                 return notify_fail("你没有准备破岳神爪，难以施展" DUAN "。\n");
  # 
  #         // 至于NPC么…这个…还是用互背的好，互背时把CLAW提前就行了。
  #         if (userp(me) && me->query_skill_prepared("cuff") == "zhenyu-quan")
  #                 return notify_fail("施展" DUAN "时破岳神爪不谊和镇狱拳法互背。\n");
  # 
  #         if ((int)me->query("neili") < 100)
  #                 return notify_fail("你现在真气不足，难以施展" DUAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "霎时间只见$N" HIY "身形一展，双爪疾攻而上，爪影笼罩$n"
  #               HIY "全身各处要穴。\n" NOR;
  #         message_combatd(msg, me, target);
  #         me->add("neili", -50);
  # 
  #         for (i = 0; i < 4; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  #                 COMBAT_D->do_attack(me, target, 0, 0);
  #         }
  #         me->start_busy(1 + random(4));
  #         return 1;
  # }
end
