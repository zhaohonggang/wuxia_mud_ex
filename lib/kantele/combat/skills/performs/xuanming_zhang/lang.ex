defmodule Kantele.Combat.Skills.Performs.XuanmingZhang.Lang do
  @moduledoc """
  perform「惊涛骇浪」（source xuanming-zhang/lang.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "strike"}, {"dp", "dodge"}, {"lvl", "xuanming-zhang"}], "level_gates": [{"xuanming-shengong", "180"}, {"xuanming-zhang", "180"}], "map_gates": [{"force", "xuanming-shengong"}], "prepared_gates": [{"strike", "xuanming-zhang"}], "resource_gates": [{"max_neili", "3000"}, {"neili", "800"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"affect_by_callbacks": [%{"buff_name": "xuanming_poison", "duration_formula": "lvl / 40 + random(lvl / 20)", "id_formula": "me->query("id")", "level_formula": "me->query("jiali") * 3"}, %{"buff_name": "xuanming_poison", "duration_formula": "lvl / 40 + random(lvl / 20)", "id_formula": "me->query("id")", "level_formula": "me->query("jiali") * 3"}], "all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的玄冥神功火候不够，无法施展", "你的玄冥神掌不够熟练，无法施展", "你的内力修为不足，无法施展", "你没有激发玄冥神功为内功，无法施展", "你没有准备玄冥神掌，无法施展", "你的真气不够，无法施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("strike") + me->query_skill("force")", "dp_formula": "target->query_skill("dodge") + target->query_skill("force")"}, "callback_functions": [%{"body": "target->affect_by("xuanming_poison",
      #                            ([ "level" : me->query("jiali") * 3,
      #                               "id"    : me->query("id"),
      #                               "duration" : lvl /", "name": "final1", "params": "object me, object target, int lvl", "return_type": "string"}, %{"body": "target->affect_by("xuanming_poison",
      #                            ([ "level" : me->query("jiali") * 3,
      #                               "id"    : me->query("id"),
      #                               "duration" : lvl /", "name": "final2", "params": "object me, object target, int lvl", "return_type": "string"}], "color_codes": ["HIM", "HIR", "HIW", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "\n$N" HIW "默运玄冥神功，展出绝招「" HIM "惊涛骇浪" HIW "」，猛然间欺身"
      #                 "向前，双掌齐出，掌风阴寒无比，掌未到，风先至，瞬息间双掌已拍向$n" HIW "！\n"NOR", "= HIM "\n$N" HIM "右掌向内一转，忽又向前，猛然间直袭$n" HIM "面门。\n" NOR", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 60,
      #                                             (: final1, me, target, lvl :))", "= HIY "$n" HIY "看见$N" HIY "来势汹涌，急忙提气跃开。\n" NOR", "HIM "\n$N" HIM "长舒一口气，左掌紧跟而出，风到掌到，正拍向$n" HIM "胸口。\n" NOR", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 70,
      #                                             (: final2, me, target, lvl :))", "= HIY "$n" HIY "看见$N" HIY "来势汹涌，急忙提气跃开。\n" NOR"], "success": []}, "damage_formula": %{"formula": "ap + random(ap / 2)"}, "do_damage_calls": [%{"attack_type": "UNARMED_ATTACK", "callback": "final1", "damage_factor": 60, "damage_var": "damage"}, %{"attack_type": "UNARMED_ATTACK", "callback": "final2", "damage_factor": 70, "damage_var": "damage"}], "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}, {"neili", "-150"}, {"neili", "-200"}, {"neili", "-75"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-150"}, {"neili", "-200"}, {"neili", "-75"}], "affect_by": ["xuanming_poison"], "apply_adds": [], "busy_lines": ["me->start_busy(4);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(4);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define LANG "「" HIM "惊涛骇浪" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # string final1(object me, object target, int lvl);
      # string final2(object me, object target, int lvl);
      # 
      # int perform(object me, object target)
      # {
      #         int damage;
      #         string msg;
      #         int ap, dp;
      #         int lvl/*, p*/;
      # 
      #         if (userp(me) && ! me->query("can_perform/xuanming-zhang/lang"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(LANG "只能对战斗中的对手使用。\n");
      # 
      #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
      #                 return notify_fail(LANG "只能空手施展。\n");
      # 
      #         if ((int)me->query_skill("xuanming-shengong", 1) < 180)
      #                 return notify_fail("你的玄冥神功火候不够，无法施展" LANG "。\n");
      # 
      #         if ((int)me->query_skill("xuanming-zhang", 1) < 180)
      #                 return notify_fail("你的玄冥神掌不够熟练，无法施展" LANG "。\n");
      # 
      #         if ((int)me->query("max_neili") < 3000)
      #                 return notify_fail("你的内力修为不足，无法施展" LANG "。\n");
      # 
      #         if (me->query_skill_mapped("force") != "xuanming-shengong")
      #                 return notify_fail("你没有激发玄冥神功为内功，无法施展" LANG "。\n");
      # 
      #         if (me->query_skill_prepared("strike") != "xuanming-zhang")
      #                 return notify_fail("你没有准备玄冥神掌，无法施展" LANG "。\n");
      # 
      #         if ((int)me->query("neili") < 800)
      #                 return notify_fail("你的真气不够，无法施展" LANG "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIW "\n$N" HIW "默运玄冥神功，展出绝招「" HIM "惊涛骇浪" HIW "」，猛然间欺身"
      #               "向前，双掌齐出，掌风阴寒无比，掌未到，风先至，瞬息间双掌已拍向$n" HIW "！\n"NOR;  
      # 
      #         lvl = me->query_skill("xuanming-zhang", 1);
      # 
      #         ap = me->query_skill("strike") + me->query_skill("force");
      #         dp = target->query_skill("dodge") + target->query_skill("force");
      # 
      #         me->start_busy(4);
      # 
      #         // 第一掌
      # 
      #         msg += HIM "\n$N" HIM "右掌向内一转，忽又向前，猛然间直袭$n" HIM "面门。\n" NOR;
      #         if (ap / 2 + random(ap) > dp)
      #         { 
      #                 damage = ap + random(ap / 2);
      #                 me->add("neili", -150);
      # 
      #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 60,
      #                                           (: final1, me, target, lvl :));
      #                                            
      #         } else
      #         {
      #                 msg += HIY "$n" HIY "看见$N" HIY "来势汹涌，急忙提气跃开。\n" NOR;
      #                 me->add("neili", -75);
      #         }
      #         message_sort(msg, me, target);
      #          
      #         // 第二掌
      #         msg = HIM "\n$N" HIM "长舒一口气，左掌紧跟而出，风到掌到，正拍向$n" HIM "胸口。\n" NOR;
      #         if (ap / 2 + random(ap) > dp)
      #         { 
      #                 damage = ap + random(ap / 2);
      #                 me->add("neili", -200);
      # 
      #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 70,
      #                                           (: final2, me, target, lvl :));
      #                                            
      #         } else
      #         {
      #                 msg += HIY "$n" HIY "看见$N" HIY "来势汹涌，急忙提气跃开。\n" NOR;
      #                 me->add("neili", -100);
      #         }
      #         message_sort(msg, me, target);
      # 
      #         return 1;
      # }
      # 
      # string final1(object me, object target, int lvl)
      # {
      #         target->affect_by("xuanming_poison",
      #                          ([ "level" : me->query("jiali") * 3,
      #                             "id"    : me->query("id"),
      #                             "duration" : lvl / 40 + random(lvl / 20) ]));
      # 
      #         return HIR "$n" HIR "正欲闪躲，却见$N" HIR "突然绕到$p" HIR "身后，$n" HIR "心中一"
      #                    "惊，背后中掌，顿觉脊梁处一股寒气升起，尽损三焦六脉。\n" NOR;
      # 
      # }
      # 
      # string final2(object me, object target, int lvl)
      # {
      #         target->affect_by("xuanming_poison",
      #                          ([ "level" : me->query("jiali") * 3,
      #                             "id"    : me->query("id"),
      #                             "duration" : lvl / 40 + random(lvl / 20) ]));
      # 
      #         return HIR "$n" HIR "但见$N" HIR "右掌已攻出，正欲反击。突然间胸口一震，不禁暗暗"
      #                "叫苦，顿感胸口处一股寒气升起，尽损三焦六脉。\n" NOR;
      # 
      # }
end
