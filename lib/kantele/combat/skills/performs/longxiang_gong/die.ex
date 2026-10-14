defmodule Kantele.Combat.Skills.Performs.LongxiangGong.Die do
  @moduledoc """
  perform「象跌势」（source longxiang-gong/perform/die.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已知此招 → 目标为战斗中的对手 → 空手 →
  龙象般若功>=240 → 内力上限>=4000 → 激发 unarmed 为龙象般若功 →
  激发 force 为龙象般若功 → 准备 unarmed 为龙象般若功 → 真气>=500 → 目标存活。
  `ap = 基本拳脚 + con*10`，目标 `dp = 招架 + dex*10`。
  - 攻击方 `max_neili > 目标 max_neili * 2`：一击「击飞」，目标 `eff_qi`/`eff_jing`
    归 1 并昏厥（`unconcious()`）；攻击方扣 50 真气、忙乱 1，直接结束；
  - 否则 `ap/2 + random(ap) > dp` 取 `count = ap/10`，失手取 `count = 0`；
    连出 5 击（`COMBAT_D->do_attack`），其间 `random(5)<2` 且目标不忙则目标忙乱 1；
  - 攻击方无条件扣 300 真气、忙乱 `1 + random(5)`。

  差异（TODO(migrate)）：
  - 起手文案中 `NOR + WHT` 的 `+` 使首段与「象跌势」分离，而「象跌势」与其后段
    只隔颜色宏会被 C 侧合并，故起手文案为两段（用 `Enum.join/2` 保持不合并）；
  - 击飞分支与命中分支都依赖目标属性，故全部结算（含起手广播）在目标侧
    `resolve_incoming/4` 完成；攻击方的内力/忙乱经 `combat/perform-feedback` 回执；
  - 5 次 `COMBAT_D->do_attack` 折算为每击 `count` 基础判定 + 伤害（同
    jiasha-fumogong/zhe）；`.c` 的 `add_temp("apply/attack", count)` / 收招 `-count`
    即该折算的数值来源；
  - `set("eff_qi", 1)`/`set("eff_jing", 1)` 折合 `vitals.max_qi/max_jing` 置 1，
    `unconcious()` 由 `Kantele.Feature.Damage.unconcious/1` 承接；
  - `living(target)` 门槛由目标侧死亡检查兜底。
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
  alias Kantele.Combat.Performs
  alias Kantele.Feature.Damage

  @perform_id "longxiang-gong/die"
  @move_name "「象跌势」"

  # LPC: for (i = 0; i < 5; i++) { ... COMBAT_D->do_attack(me, target, 0, 0); }
  @strikes 5

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    vitals = character.meta.vitals
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "longxiang-gong")
    # LPC: ap = me->query_skill("unarmed") + me->query("con") * 10;
    ap = Stats.skill(stats, "unarmed") + (stats.con || 0) * 10

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(character),
         :ok <- check_max_neili(character),
         :ok <- check_mapped(character),
         :ok <- check_mapped_force(character),
         :ok <- check_prepared(character),
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
          strikes: @strikes,
          attacker_max_neili: vitals.max_neili,
          rng: rng
        }
      })

      assign(conn, :prompt, false)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (userp(me) && ! me->query("can_perform/longxiang-gong/die"))
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
  defp check_weapon(combat) do
    if Combat.occupied?(combat, :weapon) or Combat.occupied?(combat, :secondary_weapon) do
      {:error, "#{@move_name}只能空手施展。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("longxiang-gong", 1) < 240)
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "longxiang-gong") < 240 do
      {:error, "你的龙象般若功修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query("max_neili") < 4000)
  defp check_max_neili(character) do
    if character.meta.vitals.max_neili < 4000 do
      {:error, "你的内力修为不足，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("unarmed") != "longxiang-gong")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "unarmed") != "longxiang-gong" do
      {:error, "你没有激发龙象般若功为拳脚，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("force") != "longxiang-gong")
  defp check_mapped_force(character) do
    if Stats.mapped(character.meta.stats, "force") != "longxiang-gong" do
      {:error, "你没有激发龙象般若功为内功，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_prepared("unarmed") != "longxiang-gong")
  defp check_prepared(character) do
    prepared = Stats.prepared_perform(character.meta.stats, "unarmed")

    if prepared == nil or prepared |> String.split("/") |> hd() != "longxiang-gong" do
      {:error, "你没有准备使用龙象般若功，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query("neili") < 500)
  defp check_neili(character) do
    if character.meta.vitals.neili < 500 do
      {:error, "你现在的真气不足，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (! living(target))
  defp check_target_alive(target) do
    if not dead?(target) do
      :ok
    else
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

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
    strikes = Map.get(data, :strikes, @strikes)
    attacker_max_neili = Map.get(data, :attacker_max_neili, 0)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: msg = HIY "$N" HIY "蓦地收回双掌，施出密宗绝学「" NOR + WHT "象跌势"
    #            HIY "」，双臂再度横移，猛贯向$n" HIY "！\n" NOR;
    # `NOR + WHT` 处有 `+`，故「象跌势」与首段分离；而「象跌势」与其后段之间
    # 只隔颜色宏（无 `+`），C 侧会合并，故此处为两段（须用 Enum.join 保持不合并）。
    opening =
      Enum.join(
        ["$N蓦地收回双掌，施出密宗绝学「", "象跌势」，双臂再度横移，猛贯向$n！\n"],
        ""
      )

    # LPC: dp = target->query_skill("parry") + target->query("dex") * 10;
    dp = Stats.skill(stats, "parry") + (stats.dex || 0) * 10

    # LPC: if (me->query("max_neili") > target->query("max_neili") * 2) { …击飞… return 1; }
    if attacker_max_neili > character.meta.vitals.max_neili * 2 do
      # LPC: msg += HIR "$n" HIR "全然无力阻挡，竟被$N一拳击得飞起，重重的跌落在地上。\n" NOR;
      #      me->add("neili", -50); me->start_busy(1);
      #      target->set("eff_qi", 1); target->set("eff_jing", 1); target->unconcious();
      vitals = %{character.meta.vitals | max_qi: 1, max_jing: 1}
      character = %{character | meta: %{character.meta | vitals: vitals}}

      Performs.feedback(attacker, 50, 1)

      conn =
        Broadcast.publish(
          conn,
          opening <> "$n全然无力阻挡，竟被$N一拳击得飞起，重重的跌落在地上。\n",
          bindings
        )

      character =
        case Damage.unconcious(character) do
          {:ok, c} -> c
          _ -> character
        end

      put_character(conn, character)
    else
      # LPC: if (ap / 2 + random(ap) > dp) { count = ap / 10; …呆立当场… }
      #      else { count = 0; …小心抵挡… }
      {conn, count} =
        if div(ap, 2) + Engine.rand(rng, ap) > dp do
          {Broadcast.publish(
             conn,
             opening <> "$n见$P来势迅猛之极，一时不知该如何作出抵挡，竟呆立当场。\n",
             bindings
           ), div(ap, 10)}
        else
          {Broadcast.publish(
             conn,
             opening <> "$n见$p来势迅猛之极，甚难防备，连忙振作精神，小心抵挡。\n",
             bindings
           ), 0}
        end

      # LPC: me->add_temp("apply/attack", count); me->add("neili", -300);
      #      for (i = 0; i < 5; i++) { if (! me->is_fighting(target)) break;
      #        if (random(5) < 2 && ! target->is_busy()) target->start_busy(1);
      #        COMBAT_D->do_attack(me, target, 0, 0); }
      #      me->start_busy(1 + random(5)); me->add_temp("apply/attack", -count);
      level = max(count, 1)
      dodge = Stats.skill(stats, "dodge")

      {combat, damage} =
        Enum.reduce(1..strikes, {character.meta.combat, 0}, fn _, {combat_acc, damage_acc} ->
          combat_acc =
            if Engine.rand(rng, 5) < 2 and not Combat.busy?(combat_acc) do
              Combat.start_busy(combat_acc, 1)
            else
              combat_acc
            end

          if div(level, 2) + Engine.rand(rng, level) > dodge do
            {combat_acc, damage_acc + level + Engine.rand(rng, level)}
          else
            {combat_acc, damage_acc}
          end
        end)

      vitals =
        if damage > 0 do
          character.meta.vitals
          |> Vitals.damage(:qi, damage)
          |> Vitals.wound(:qi, div(damage, 3))
        else
          character.meta.vitals
        end

      character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

      Performs.feedback(attacker, 300, 1 + Engine.rand(rng, 5))

      put_character(conn, character)
    end
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define DIE "「" WHT "象跌势" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  # //      object weapon;
  #         int ap, dp;
  #         int i, count;
  #         string msg;
  # 
  #         if (userp(me) && ! me->query("can_perform/longxiang-gong/die"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(DIE "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(DIE "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("longxiang-gong", 1) < 240)
  #                 return notify_fail("你的龙象般若功修为不够，难以施展" DIE "。\n");
  # 
  #         if (me->query("max_neili") < 4000)
  #                 return notify_fail("你的内力修为不足，难以施展" DIE "。\n");
  # 
  #         if (me->query_skill_mapped("unarmed") != "longxiang-gong")
  #                 return notify_fail("你没有激发龙象般若功为拳脚，难以施展" DIE "。\n");
  # 
  #         if (me->query_skill_mapped("force") != "longxiang-gong")
  #                 return notify_fail("你没有激发龙象般若功为内功，难以施展" DIE "。\n");
  # 
  #         if (me->query_skill_prepared("unarmed") != "longxiang-gong")
  #                 return notify_fail("你没有准备使用龙象般若功，难以施展" DIE "。\n");
  # 
  #         if (me->query("neili") < 500)
  #                 return notify_fail("你现在的真气不足，难以施展" DIE "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "$N" HIY "蓦地收回双掌，施出密宗绝学「" NOR + WHT "象跌势"
  #               HIY "」，双臂再度横移，猛贯向$n" HIY "！\n" NOR;
  # 
  #         ap = me->query_skill("unarmed") + me->query("con") * 10;
  #         dp = target->query_skill("parry") + target->query("dex") * 10;
  # 
  #         if (me->query("max_neili") > target->query("max_neili") * 2)
  #     {
  #                 msg += HIR "$n" HIR "全然无力阻挡，竟被$N"
  #                        HIR "一拳击得飞起，重重的跌落在地上。\n" NOR;
  #             me->add("neili", -50);
  #                 me->start_busy(1);
  # 
  #             message_combatd(msg, me, target);
  # 
  #                 target->set("eff_qi", 1);
  #                 target->set("eff_jing", 1);
  #                 target->unconcious();
  # 
  #             return 1;
  #     } else
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 count = ap / 10;
  #                 msg += HIR "$n" HIR "见$P" HIR "来势迅猛之极，一时不知该如"
  #                        "何作出抵挡，竟呆立当场。\n" NOR;
  #         } else
  #         {
  #                 msg += HIY "$n" HIY "见$p" HIY "来势迅猛之极，甚难防备，连"
  #                        "忙振作精神，小心抵挡。\n" NOR;
  #                 count = 0;
  #         }
  # 
  #         message_combatd(msg, me, target);
  #         me->add_temp("apply/attack", count);
  # 
  #         me->add("neili", -300);
  # 
  #         for (i = 0; i < 5; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  #                 if (random(5) < 2 && ! target->is_busy())
  #                         target->start_busy(1);
  # 
  #                 COMBAT_D->do_attack(me, target, 0, 0);
  #         }
  # 
  #         me->start_busy(1 + random(5));
  #         me->add_temp("apply/attack", -count);
  # 
  #         return 1;
  # }
end
