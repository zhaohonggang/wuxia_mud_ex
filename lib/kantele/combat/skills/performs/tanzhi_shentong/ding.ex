defmodule Kantele.Combat.Skills.Performs.TanzhiShentong.Ding do
  @moduledoc """
  perform「定昆仑」（source tanzhi-shentong/ding.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "finger"}, {"dp", "parry"}], "level_gates": [{"jingluo-xue", "120"}, {"tanzhi-shentong", "120"}], "map_gates": [{"finger", "tanzhi-shentong"}], "prepared_gates": [{"finger", "tanzhi-shentong"}], "resource_gates": [{"max_neili", "1500"}, {"neili", "300"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "对方现在已经无法控制真气，放胆攻击吧。\n", "你的弹指神通不够娴熟，难以施展", "你对经络学的了解不够，难以施展", "你没有激发弹指神通，难以施展", "你没有准备弹指神通，难以施展", "你的内力修为不足，难以施展", "你现在的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("finger")", "dp_formula": "target->query_skill("parry")"}, "buff_delete": ["no_perform"], "callback_functions": [%{"body": "target->set_temp("no_perform", 1);
      #           call_out("ding_end", 1 + random(5), me, target);
      #           return HIR "$n" HIR "只觉眼前寒芒一闪而过，随即全身一阵"
      #                  "刺痛，几股血柱自身上射出。\n$p陡然间一提真气，"
      #                  "竟", "name": "final", "params": "object me, object target", "return_type": "string"}, %{"body": "if (target && target->query_temp("no_perform"))
      #           {
      #                   if (living(target))
      #                   {
      #                           message_combatd(HIC "$N" HIC "深深吸入一口"
      #                             ", "name": "ding_end", "params": "object me, object target", "return_type": "void"}], "color_codes": ["CYN", "HIC", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIC "$N" HIC "合指轻弹，顿时只听“飕”的一声，一缕若有若无的"
      #                 "罡气已朝$n" HIC "电射而去。\n" NOR", "= COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, 0, (: final, me, target, 0 :))", "= CYN "可是$p" CYN "看破了$P" CYN
      #                          "的企图，轻轻一跃，跳了开去。\n" NOR"], "success": ["=  HIR "$n" HIR "只觉胁下一麻，已被$P"
      #                           HIR "指气射中，全身酸软无力，呆立当场。\n" NOR"]}, "damage_formula": %{"formula": "ap / 4 + random(ap / 2)"}, "do_damage_calls": [%{"attack_type": "REMOTE_ATTACK", "callback": "final", "damage_factor": 0, "damage_var": "damage"}], "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-150"}, {"neili", "-200"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-150"}, {"neili", "-200"}], "affect_by": [], "apply_adds": [], "busy_lines": ["//if (target->is_busy())", "target->start_busy(ap / 30 + 2);", "me->start_busy(2);", "me->start_busy(1);"], "remote_damage": true, "set_flags": [], "temp_set": ["no_perform"]}
      #   - //if (target->is_busy())
      #   - target->start_busy(ap / 30 + 2);
      #   - me->start_busy(2);
      #   - me->start_busy(1);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define DING "「" HIC "定昆仑" NOR "」"
      # 
      # string final(object me, object target);
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         string msg;
      #         int ap, dp;
      #         int damage;
      # 
      #         if (userp(me) && ! me->query("can_perform/tanzhi-shentong/ding"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(DING "只能对战斗中的对手使用。\n");
      # 
      #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
      #                 return notify_fail(DING "只能空手施展。\n");
      # 
      #         //if (target->is_busy())
      #         //        return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
      #         if (target->query_temp("no_perform"))
      #                 return notify_fail("对方现在已经无法控制真气，放胆攻击吧。\n");
      # 
      #         if ((int)me->query_skill("tanzhi-shentong", 1) < 120)
      #                 return notify_fail("你的弹指神通不够娴熟，难以施展" DING "。\n");
      # 
      #         if ((int)me->query_skill("jingluo-xue", 1) < 120)
      #                 return notify_fail("你对经络学的了解不够，难以施展" DING "。\n");
      # 
      #         if (me->query_skill_mapped("finger") != "tanzhi-shentong")
      #                 return notify_fail("你没有激发弹指神通，难以施展" DING "。\n");
      # 
      #         if (me->query_skill_prepared("finger") != "tanzhi-shentong")
      #                 return notify_fail("你没有准备弹指神通，难以施展" DING "。\n");
      # 
      #         if (me->query("max_neili") < 1500)
      #                 return notify_fail("你的内力修为不足，难以施展" DING "。\n");
      # 
      #         if (me->query("neili") < 300)
      #                 return notify_fail("你现在的真气不够，难以施展" DING "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIC "$N" HIC "合指轻弹，顿时只听“飕”的一声，一缕若有若无的"
      #               "罡气已朝$n" HIC "电射而去。\n" NOR;
      # 
      #         ap = me->query_skill("finger");
      #         dp = target->query_skill("parry");
      # 
      #         if (ap / 2 + random(ap) > dp)
      #         {
      # /*                msg +=  HIR "$n" HIR "只觉胁下一麻，已被$P"
      #                         HIR "指气射中，全身酸软无力，呆立当场。\n" NOR;
      #                 target->start_busy(ap / 30 + 2);
      # */
      #                 damage = ap / 4 + random(ap / 2);
      #                 msg += COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, 0, (: final, me, target, 0 :));
      #                 me->start_busy(2);
      #                 me->add("neili", -200);
      # 
      #         } else
      #         {
      #                 msg += CYN "可是$p" CYN "看破了$P" CYN
      #                        "的企图，轻轻一跃，跳了开去。\n" NOR;
      #                 me->start_busy(1);
      #                 me->add("neili", -150);
      #         }
      #         message_combatd(msg, me, target);
      #         return 1;
      # }
      # 
      # string final(object me, object target)
      # {
      #         target->set_temp("no_perform", 1);
      #         call_out("ding_end", 1 + random(5), me, target);
      #         return HIR "$n" HIR "只觉眼前寒芒一闪而过，随即全身一阵"
      #                "刺痛，几股血柱自身上射出。\n$p陡然间一提真气，"
      #                "竟发现周身力道竟似涣散一般，全然无法控制。\n" NOR;
      # }
      # 
      # void ding_end(object me, object target)
      # {
      #         if (target && target->query_temp("no_perform"))
      #         {
      #                 if (living(target))
      #                 {
      #                         message_combatd(HIC "$N" HIC "深深吸入一口"
      #                                         "气，脸色由白转红，看起来好"
      #                                         "多了。\n" NOR, target);
      # 
      #                         tell_object(target, HIY "你感到被扰乱的真气"
      #                                             "慢慢平静了下来。\n" NOR);
      #                 }
      #                 target->delete_temp("no_perform");
      #     }
      #     return;
      # }
end
