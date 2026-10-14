defmodule Kantele.Combat.Skills.Performs.LongxiangGong.Zhen do
  @moduledoc """
  perform「真·般若极」（source longxiang-gong/perform/zhen.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已知此招 → 目标为战斗中的对手 → 空手 →
  龙象般若功>=390 → 内力上限>=7000 → 激发 unarmed 为龙象般若功 →
  激发 force 为龙象般若功 → 准备 unarmed 为龙象般若功 → 真气>=1000 → 目标存活。
  `ap = 基本拳脚 + con*10`，目标 `dp = 招架 + dex*10`。
  - `ap*2/3 + random(ap) > dp` 且 `max_neili/2 + random(max_neili/2) > 目标 max_neili*5/4`：
    一击「击飞」并令目标昏厥（`unconcious()`）；攻击方扣 100 真气、忙乱 1，直接结束；
  - 命中但未「击飞」：伤害 `ap/2 + random(jiali*5)`（外伤 90%），追加「呆立当场」文案，
    取 `count = ap/10`；攻击方扣 600 真气、忙乱 `1 + random(6)`；
  - 未命中：取 `count = 0`，追加「小心抵挡」文案，攻击方扣 600 真气、忙乱 `1 + random(6)`；
  - 后两路随后连出 8 击（`COMBAT_D->do_attack`），其间 `random(5)<2` 且目标不忙则目标忙乱 1。

  差异（TODO(migrate)）：
  - 起手文案（含一段字符画）与命中结算依赖目标属性，故全部结算（含起手广播）在目标侧
    `resolve_incoming/4` 完成；攻击方的内力/忙乱经 `combat/perform-feedback` 回执；
  - 8 次 `COMBAT_D->do_attack` 折算为每击 `count` 基础判定 + 伤害（同
    jiasha-fumogong/zhe）；`.c` 的 `add_temp("apply/attack", count)` / 收招 `-count`
    即该折算的数值来源；
  - `COMBAT_D->do_damage(..., UNARMED_ATTACK, damage, 90, …)` 折算为
    `Vitals.damage(:qi, damage)` + `Vitals.wound(:qi, damage*90/100)`；
  - `me->query("jiali")` 随事件数据下发（`combat.jiali`）；
  - `target->unconcious()` 由 `Kantele.Feature.Damage.unconcious/1` 承接；
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

  @perform_id "longxiang-gong/zhen"
  @move_name "「真·般若极」"

  # LPC: for (i = 0; i < 8; i++) { ... COMBAT_D->do_attack(me, target, 0, 0); }
  @strikes 8

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
          jiali: combat.jiali,
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

  # LPC: if (userp(me) && ! me->query("can_perform/longxiang-gong/zhen"))
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

  # LPC: if ((int)me->query_skill("longxiang-gong", 1) < 390)
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "longxiang-gong") < 390 do
      {:error, "你的龙象般若功修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query("max_neili") < 7000)
  defp check_max_neili(character) do
    if character.meta.vitals.max_neili < 7000 do
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

  # LPC: if (me->query("neili") < 1000)
  defp check_neili(character) do
    if character.meta.vitals.neili < 1000 do
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
    attacker_max_neili = Map.get(data, :attacker_max_neili, 0)
    jiali = Map.get(data, :jiali, 0)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: msg = HIY "$N" HIY "仰天一声怒嚎，将龙象般若功提运至极限，全身顿时罡劲"
    #            "迸发，真气蒸腾而出，笼罩$N" HIY "\n四方！电光火石间，$N" HIY "双"
    #            "拳已携着雷霆万钧之势崩击而出，卷起万里尘埃，正是密宗绝学：\n\n" NOR;
    opening =
      "$N仰天一声怒嚎，将龙象般若功提运至极限，全身顿时罡劲迸发，真气蒸腾而出，笼罩$N\n四方！电光火石间，$N双拳已携着雷霆万钧之势崩击而出，卷起万里尘埃，正是密宗绝学：\n\n"

    # LPC: msg += HIW "        般      般般般 …（字符画，共 9 行）… \n\n" NOR;
    ascii =
      "        般      般般般           若        若           极    极极极极极极\n" <>
        "    般般般般    般  般       若若若若若若若若若若       极       极    极\n" <>
        "    般    般    般  般           若        若       极极极极极  极    极\n" <>
        "    般 般 般 般般    般般          若                 极极极  极极极 极极极\n" <>
        "  般般般般般般             若若若若若若若若若若若若  极 极 极  极极     极\n" <>
        "    般    般   般般般般         若                   极 极 极  极 极   极\n" <>
        "    般 般 般    般  般        若 若若若若若若若      极 极 极 极   极极\n" <>
        "    般    般     般般       若   若          若         极   极     极\n" <>
        "   般    般   般般  般般         若若若若若若若         极  极  极极极极极\n\n"

    # LPC: msg += HIY "$N" HIY "一道掌力打出，接着便涌出了第二道、第三道掌力，掌势"
    #            "连绵不绝，气势如虹！直到$N" HIY "\n第十三道掌力打完，四周所笼罩"
    #            "着的罡劲方才慢慢消退！而$n" HIY "此时却已是避无可避！\n\n" NOR;
    palm13 =
      "$N一道掌力打出，接着便涌出了第二道、第三道掌力，掌势连绵不绝，气势如虹！直到$N\n第十三道掌力打完，四周所笼罩着的罡劲方才慢慢消退！而$n此时却已是避无可避！\n\n"

    head = opening <> ascii <> palm13

    # LPC: dp = target->query_skill("parry") + target->query("dex") * 10;
    dp = Stats.skill(stats, "parry") + (stats.dex || 0) * 10

    # LPC: if (ap * 2 / 3 + random(ap) > dp)
    if div(ap * 2, 3) + Engine.rand(rng, ap) > dp do
      # LPC: if (me->query("max_neili") / 2 + random(me->query("max_neili") / 2)
      #            > target->query("max_neili") * 5 / 4) { …击飞… target->unconcious(); return 1; }
      if div(attacker_max_neili, 2) + Engine.rand(rng, div(attacker_max_neili, 2)) >
           div(character.meta.vitals.max_neili * 5, 4) do
        # LPC: msg += HIR "$n" HIR "全然无力阻挡，竟被$N一下击得飞起，重重的跌落在地上。\n" NOR;
        #      me->add("neili", -100); me->start_busy(1);
        Performs.feedback(attacker, 100, 1)

        conn =
          Broadcast.publish(
            conn,
            head <> "$n全然无力阻挡，竟被$N一下击得飞起，重重的跌落在地上。\n",
            bindings
          )

        character =
          case Damage.unconcious(character) do
            {:ok, c} -> c
            _ -> character
          end

        put_character(conn, character)
      else
        # LPC: jia = me->query("jiali"); damage = ap / 2 + random(jia * 5);
        #      msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 90, …);
        #      msg += HIR "$n" HIR "被$N" HIR "罡劲所逼，一时无力作出抵挡，竟呆立当场。\n" NOR;
        #      count = ap / 10;
        damage = div(ap, 2) + Engine.rand(rng, jiali * 5)

        vitals =
          character.meta.vitals
          |> Vitals.damage(:qi, damage)
          |> Vitals.wound(:qi, div(damage * 90, 100))

        character = %{character | meta: %{character.meta | vitals: vitals}}

        Performs.feedback(attacker, 600, 1 + Engine.rand(rng, 6))

        # `.c` 此处为两条独立 `msg +=`，故两段文案须保持分离（不能用 `<>` 直接相连）。
        hit_msg = head <> "$n不及闪避，顿被$N一下击中，尽伤三焦六脉。\n"

        conn =
          Broadcast.publish(
            conn,
            hit_msg <> "$n被$N罡劲所逼，一时无力作出抵挡，竟呆立当场。\n",
            bindings
          )

        finish_strikes(conn, character, div(ap, 10), rng)
      end
    else
      # LPC: msg += HIY "$n" HIY "见$N" HIY "来势迅猛之极，甚难防备，连"
      #            "忙振作精神，小心抵挡。\n" NOR; count = 0;
      #      me->add("neili", -600); me->start_busy(1 + random(6));
      Performs.feedback(attacker, 600, 1 + Engine.rand(rng, 6))

      conn =
        Broadcast.publish(
          conn,
          head <> "$n见$N来势迅猛之极，甚难防备，连忙振作精神，小心抵挡。\n",
          bindings
        )

      finish_strikes(conn, character, 0, rng)
    end
  end

  # LPC: me->add_temp("apply/attack", count);
  #      for (i = 0; i < 8; i++) { if (! me->is_fighting(target)) break;
  #        if (random(5) < 2 && ! target->is_busy()) target->start_busy(1);
  #        COMBAT_D->do_attack(me, target, 0, 0); }
  defp finish_strikes(conn, character, count, rng) do
    level = max(count, 1)
    dodge = Stats.skill(character.meta.stats, "dodge")

    {combat, damage} =
      Enum.reduce(1..@strikes, {character.meta.combat, 0}, fn _, {combat_acc, damage_acc} ->
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

    put_character(conn, character)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define ZHEN "「" HIW "真·般若极" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         // object weapon;
  #         int ap, dp, damage, jia;
  #         int i, count;
  #         string msg;
  # 
  #         if (userp(me) && ! me->query("can_perform/longxiang-gong/zhen"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(ZHEN "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(ZHEN "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("longxiang-gong", 1) < 390)
  #                 return notify_fail("你的龙象般若功修为不够，难以施展" ZHEN "。\n");
  # 
  #         if (me->query("max_neili") < 7000)
  #                 return notify_fail("你的内力修为不足，难以施展" ZHEN "。\n");
  # 
  #         if (me->query_skill_mapped("unarmed") != "longxiang-gong")
  #                 return notify_fail("你没有激发龙象般若功为拳脚，难以施展" ZHEN "。\n");
  # 
  #         if (me->query_skill_mapped("force") != "longxiang-gong")
  #                 return notify_fail("你没有激发龙象般若功为内功，难以施展" ZHEN "。\n");
  # 
  #         if (me->query_skill_prepared("unarmed") != "longxiang-gong")
  #                 return notify_fail("你没有准备使用龙象般若功，难以施展" ZHEN "。\n");
  # 
  #         if (me->query("neili") < 1000)
  #                 return notify_fail("你现在的真气不足，难以施展" ZHEN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "$N" HIY "仰天一声怒嚎，将龙象般若功提运至极限，全身顿时罡劲"
  #               "迸发，真气蒸腾而出，笼罩$N" HIY "\n四方！电光火石间，$N" HIY "双"
  #               "拳已携着雷霆万钧之势崩击而出，卷起万里尘埃，正是密宗绝学：\n\n" NOR;
  # 
  #         msg += HIW
  #         "        般      般般般           若        若           极    极极极极极极\n"
  #         "    般般般般    般  般       若若若若若若若若若若       极       极    极\n"
  #         "    般    般    般  般           若        若       极极极极极  极    极\n"
  #         "    般 般 般 般般    般般          若                 极极极  极极极 极极极\n"
  #         "  般般般般般般             若若若若若若若若若若若若  极 极 极  极极     极\n"
  #         "    般    般   般般般般         若                   极 极 极  极 极   极\n"
  #         "    般 般 般    般  般        若 若若若若若若若      极 极 极 极   极极\n"
  #         "    般    般     般般       若   若          若         极   极     极\n"
  #         "   般    般   般般  般般         若若若若若若若         极  极  极极极极极\n\n" NOR;
  # 
  #         msg += HIY "$N" HIY "一道掌力打出，接着便涌出了第二道、第三道掌力，掌势"
  #                "连绵不绝，气势如虹！直到$N" HIY "\n第十三道掌力打完，四周所笼罩"
  #                "着的罡劲方才慢慢消退！而$n" HIY "此时却已是避无可避！\n\n" NOR;
  # 
  #         ap = me->query_skill("unarmed") + me->query("con") * 10;
  #         dp = target->query_skill("parry") + target->query("dex") * 10;
  # 
  #         if (ap * 2 / 3 + random(ap) > dp)
  # {
  #         if (me->query("max_neili") / 2 + random(me->query("max_neili") / 2) > target->query("max_neili") * 5/4)
  #     {
  #                 msg += HIR "$n" HIR "全然无力阻挡，竟被$N"
  #                        HIR "一下击得飞起，重重的跌落在地上。\n" NOR;
  #             me->add("neili", -100);
  #           me->start_busy(1);
  # 
  #             message_combatd(msg, me, target);
  # 
  #                 target->unconcious();
  # 
  #             return 1;
  #     } else
  #         {
  #             jia = me->query("jiali");
  #                 damage = ap / 2 + random(jia * 5);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 90,
  #                                                    HIR "$n" HIR "不及闪避，顿被$N" HIR
  #                                 HIR "一下击中，尽伤三焦六脉。\n" NOR);
  #                         msg += HIR "$n" HIR "被$N" HIR "罡劲所逼，一时无力作出抵挡，竟呆立当场。\n" NOR;
  #                         count = ap / 10;
  #         }
  # } else
  #         {
  #                 msg += HIY "$n" HIY "见$N" HIY "来势迅猛之极，甚难防备，连"
  #                        "忙振作精神，小心抵挡。\n" NOR;
  #                 count = 0;
  #         }
  # 
  #         message_combatd(msg, me, target);
  #         me->add_temp("apply/attack", count);
  # 
  #         me->add("neili", -600);
  # 
  #         for (i = 0; i < 8; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  #                 if (random(5) < 2 && ! target->is_busy())
  #                         target->start_busy(1);
  # 
  #                 COMBAT_D->do_attack(me, target, 0, 0);
  #         }
  # 
  #         me->start_busy(1 + random(6));
  #         me->add_temp("apply/attack", -count);
  # 
  #         return 1;
  # 
  # }
end
