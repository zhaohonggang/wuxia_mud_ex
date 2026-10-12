defmodule Kantele.Combat.Skills.Performs.GuhongZhang.Qian do
  @moduledoc """
  perform「千山孤鸿影」（source guhong-zhang/qian.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已学此招 → 目标在战斗中 → 空手（主/副兵器皆无）→
  孤鸿掌法>=80 → 激发 `strike` 为孤鸿掌法 → 准备孤鸿掌法 → 内功>=100 →
  真气>=200 → 目标存活。
  起手广播后按 `random(ap) > 目标 parry/2` 判定：命中则攻击方 `apply/attack +10`
  （仅作用于随后的连击）；连击次数 `attack_time = min(3 + random(ap/40), 6)`，
  攻击方扣 `attack_time*20` 真气并忙乱 `1 + random(attack_time)`。

  差异（TODO(migrate)）：
  - `attack_time` 在 `.c` 中未初始化（LPC 视为 0），此处按 `0 + 3 + random(ap/40)`
    取值并封顶 6；
  - `COMBAT_D->do_attack(me, target, 0, 0)`（完整 AP/DP/招架/伤害管线）折算为每击
    `ap/10` 基础伤害 + 命中判定 `ap/2 + apply/attack 加成` + `random(ap)` vs 目标
    `dodge`（同 `daojian_guizhen/xue.ex`）；
  - `.c` 的 `message_sort` / `message_vision` 均折算为房间广播；
  - `.c` 未列「是否已学此招」门槛（`can_perform`），本引擎以框架层
    `perform_known?/2` 统一把关（多出的文案不影响对齐）；
  - `living(target)` 门槛在攻击方无 meta 可查，此处保守恒判存活，
    由目标侧 `combat/perform-incoming` 的死亡检查兜底。
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

  @perform_id "guhong-zhang/qian"
  @move_name "「千山孤鸿影」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    ap = Stats.skill(stats, "strike")
    lvl = Stats.skill(stats, "guhong-zhang")
    # LPC: attack_time += 3 + random(ap / 40); if (attack_time > 6) attack_time = 6;
    attack_time = min(3 + Engine.rand(rng, div(ap, 40)), 6)

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_empty_handed(character),
         :ok <- check_level(stats),
         :ok <- check_mapped(stats),
         :ok <- check_prepared(stats),
         :ok <- check_force(stats),
         :ok <- check_neili(character),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          ap: ap,
          attack_time: attack_time,
          rng: rng
        }
      })

      apply_effect(conn, character, target, attack_time, rng)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # 框架层「是否已学此招」门槛（.c 未列 `can_perform`，见 moduledoc 差异说明）。
  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  defp check_empty_handed(character) do
    combat = character.meta.combat

    if Combat.occupied?(combat, :weapon) or Combat.occupied?(combat, :secondary_weapon) do
      {:error, "#{@move_name}只能空手施展。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("guhong-zhang", 1) < 80)
  defp check_level(stats) do
    if Stats.skill(stats, "guhong-zhang") < 80 do
      {:error, "你孤鸿掌法不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("strike") != "guhong-zhang")
  defp check_mapped(stats) do
    if Stats.mapped(stats, "strike") != "guhong-zhang" do
      {:error, "你没有激发孤鸿掌法，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_prepared("strike") != "guhong-zhang")
  defp check_prepared(stats) do
    prepared = Stats.prepared_perform(stats, "strike")

    if is_binary(prepared) and String.split(prepared, "/") |> hd() == "guhong-zhang" do
      :ok
    else
      {:error, "你没有准备孤鸿掌法，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill("force") < 100)
  defp check_force(stats) do
    if Stats.skill(stats, "force") < 100 do
      {:error, "你的内功修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 200)
  defp check_neili(character) do
    if character.meta.vitals.neili < 200 do
      {:error, "你现在的真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (! living(target))
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

  defp apply_effect(conn, character, target, attack_time, rng) do
    # LPC: msg = HIC "\n$N" HIC "双掌陡然连续拍出，刚中带柔，一招"
    #            "「" HIG "千山孤鸿影" HIC "」，双掌带风，已将$n"
    #            HIC "笼罩在掌风之中。\n" NOR;
    #      message_sort(msg, me, target);
    conn =
      Broadcast.publish(
        conn,
        "\n$N双掌陡然连续拍出，刚中带柔，一招「千山孤鸿影」，双掌带风，已将$n笼罩在掌风之中。\n",
        n1: character.name,
        n2: target.name
      )

    # LPC: me->add("neili", -attack_time * 20); … me->start_busy(1 + random(attack_time));
    vitals = character.meta.vitals
    vitals = %{vitals | neili: max(vitals.neili - attack_time * 20, 0)}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    combat = Combat.start_busy(character.meta.combat, 1 + Engine.rand(rng, attack_time))
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
    if character.meta.combat.dead do
      conn
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    attack_time = max(Map.get(data, :attack_time, 1), 1)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("parry");
    #      if (random(ap) > dp / 2) { msg = "结果$n目不暇接…"; me->add_temp("apply/attack", 10); }
    #      else { msg = "$n看清$N这几招的来路…"; }
    #      message_vision(msg, me, target);
    hit = Engine.rand(rng, ap) > div(Stats.skill(stats, "parry"), 2)

    conn =
      if hit do
        Broadcast.publish(
          conn,
          "结果$n目不暇接，顿时被$N掌风所困，顿时阵脚大乱。\n",
          bindings
        )
      else
        Broadcast.publish(
          conn,
          "$n看清$N这几招的来路，但内劲所至，刚柔并济，也只得小心抵挡。\n",
          bindings
        )
      end

    # LPC: for (i = 0; i < attack_time; i++) { if (! me->is_fighting(target)) break;
    #        COMBAT_D->do_attack(me, target, 0, 0); }
    # 折算：每击 ap/10 基础伤害 + 命中判定 ap/2 + apply/attack 加成 + random(ap) vs dodge。
    bonus = if hit, do: 10, else: 0
    dodge = Stats.skill(stats, "dodge")
    per_hit = max(div(ap, 10), 1)

    damage =
      Enum.reduce(1..attack_time, 0, fn _, acc ->
        if div(ap, 2) + bonus + Engine.rand(rng, ap) > dodge do
          acc + per_hit + Engine.rand(rng, per_hit)
        else
          acc
        end
      end)

    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, damage)
      |> Vitals.wound(:qi, div(damage, 3))

    character = %{character | meta: %{character.meta | vitals: vitals}}

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define QIAN "「" HIG "千山孤鸿影" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         string msg;
  #         int ap, dp;
  #         int attack_time, i;
  # 
  #         if (userp(me) && ! me->query("can_perform/guhong-zhang/qian"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(QIAN "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(QIAN "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("guhong-zhang", 1) < 80)
  #                 return notify_fail("你孤鸿掌法不够娴熟，难以施展" QIAN "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "guhong-zhang")
  #                 return notify_fail("你没有激发孤鸿掌法，难以施展" QIAN "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "guhong-zhang")
  #                 return notify_fail("你没有准备孤鸿掌法，难以施展" QIAN "。\n");
  # 
  #         if (me->query_skill("force") < 100)
  #                 return notify_fail("你的内功修为不够，难以施展" QIAN "。\n");
  # 
  #         if ((int)me->query("neili") < 200)
  #                 return notify_fail("你现在的真气不够，难以施展" QIAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         ap = me->query_skill("strike");
  #         dp = target->query_skill("parry");
  # 
  #         msg = HIC "\n$N" HIC "双掌陡然连续拍出，刚中带柔，一招"
  #               "「" HIG "千山孤鸿影" HIC "」，双掌带风，已将$n"
  #               HIC "笼罩在掌风之中。\n" NOR;
  #         message_sort(msg, me, target);
  # 
  #     if (random(ap) > dp / 2)
  #     {
  #         msg = HIR "结果$n" HIR "目不暇接，顿时被$N" HIR "掌"
  #                       "风所困，顿时阵脚大乱。\n" NOR;
  #                 me->add_temp("apply/attack", 10);
  #         } else
  #         {
  #                 msg = HIY "$n" HIY "看清$N" HIY "这几招的来路，但"
  #                       "内劲所至，刚柔并济，也只得小心抵挡。\n" NOR;
  #         }
  #     message_vision(msg, me, target);
  # 
  #         attack_time += 3 + random(ap / 40);
  # 
  #         if (attack_time > 6)
  #                 attack_time = 6;
  # 
  #     me->add("neili", -attack_time * 20);
  # 
  #     for (i = 0; i < attack_time; i++)
  #     {
  #         if (! me->is_fighting(target))
  #             break;
  #                 COMBAT_D->do_attack(me, target, 0, 0);
  #     }
  #     me->start_busy(1 + random(attack_time));
  #         me->add_temp("apply/attack", -10);
  # 
  #     return 1;
  # }
end
