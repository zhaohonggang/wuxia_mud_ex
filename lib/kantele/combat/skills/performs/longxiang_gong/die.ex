defmodule Kantele.Combat.Skills.Performs.LongxiangGong.Die do
  @moduledoc """
  perform「象跌势」（source longxiang-gong/die.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

  TODO(migrate): 样本人工校对后，把以下门槛/语义写进 check_* 与 apply_effect。
  以上注释行（TODO(migrate)）校对完成后删除。
  """

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character

    with :ok <- check_gates(character) do
      apply_effect(conn, character)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # TODO(migrate) 提取器门槛事实（核对后替换为真实查法）：
      #   %{"assign_refs": [{"ap", "unarmed"}, {"dp", "parry"}], "level_gates": [{"longxiang-gong", "240"}], "map_gates": [{"force", "longxiang-gong"}, {"unarmed", "longxiang-gong"}], "prepared_gates": [{"unarmed", "longxiang-gong"}], "resource_gates": [{"max_neili", "4000"}, {"neili", "500"}], "var_gates": [{"i", "5"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的龙象般若功修为不够，难以施展", "你的内力修为不足，难以施展", "你没有激发龙象般若功为拳脚，难以施展", "你没有激发龙象般若功为内功，难以施展", "你没有准备使用龙象般若功，难以施展", "你现在的真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("unarmed") + me->query("con") * 10", "dp_formula": "target->query_skill("parry") + target->query("dex") * 10"}, "color_codes": ["HIR", "HIY", "NOR", "WHT"], "combat_messages": %{"fail": [], "other": ["HIY "$N" HIY "蓦地收回双掌，施出密宗绝学「" NOR + WHT "象跌势"
      #                 HIY "」，双臂再度横移，猛贯向$n" HIY "！\n" NOR", "= HIY "$n" HIY "见$p" HIY "来势迅猛之极，甚难防备，连"
      #                          "忙振作精神，小心抵挡。\n" NOR"], "success": ["= HIR "$n" HIR "全然无力阻挡，竟被$N"
      #                          HIR "一拳击得飞起，重重的跌落在地上。\n" NOR", "= HIR "$n" HIR "见$P" HIR "来势迅猛之极，一时不知该如"
      #                          "何作出抵挡，竟呆立当场。\n" NOR"]}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-300"}, {"neili", "-50"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-300"}, {"neili", "-50"}], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["me->start_busy(1);", "if (random(5) < 2 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(5));"], "remote_damage": false, "set_flags": [{"eff_jing", "1"}, {"eff_qi", "1"}], "temp_set": []}
      #   - me->start_busy(1);
      #   - if (random(5) < 2 && ! target->is_busy())
      #   - target->start_busy(1);
      #   - me->start_busy(1 + random(5));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
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
