defmodule Kantele.Combat.Skills.Performs.TieZhang.Yin do
  @moduledoc """
  perform「阴阳磨」（source tie-zhang/yin.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "strike"}, {"dd", "dodge"}, {"dp", "parry"}, {"lvl", "strike"}], "level_gates": [{"force", "300"}, {"tie-zhang", "220"}], "map_gates": [{"strike", "tie-zhang"}], "prepared_gates": [{"strike", "tie-zhang"}], "resource_gates": [{"max_neili", "3500"}, {"neili", "500"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"affect_by_callbacks": [%{"buff_name": "tiezhang_yin", "duration_formula": "lvl / 50 + random(lvl / 50)", "id_formula": "me->query("id")", "level_formula": "me->query("jiali") + random(me->query("jiali") / 2)"}, %{"buff_name": "tiezhang_yang", "duration_formula": "lvl / 50 + random(lvl / 50)", "id_formula": "me->query("id")", "level_formula": "me->query("jiali") + random(me->query("jiali") / 2)"}], "all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你铁掌掌法火候不够，难以施展", "你没有激发铁掌掌法，难以施展", "你没有准备铁掌掌法，难以施展", "你的内功修为不够，难以施展", "你的内力修为不够，难以施展", "你现在的真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("strike") + me->query("str") * 5", "dp_formula": "target->query_skill("parry") + target->query("con") * 5"}, "callback_functions": [%{"body": "int lvl;
      #           lvl = me->query_skill("strike");
      #   
      #           target->affect_by("tiezhang_yin",
      #                          ([ "level" : me->query("jiali") + random(me->query("jiali") / 2),
      #                     ", "name": "finala", "params": "object me, object target, int damage", "return_type": "string"}, %{"body": "int lvl;
      #           lvl = me->query_skill("strike");
      #   
      #           target->affect_by("tiezhang_yang",
      #                          ([ "level" : me->query("jiali") + random(me->query("jiali") / 2),
      #                    ", "name": "finalb", "params": "object me, object target, int damage", "return_type": "string"}], "color_codes": ["CYN", "HIR", "HIW", "NOR"], "combat_exp_formulas": [{"lvl", "to_int(pow(to_float(me->query("combat_exp") * 10), 1.0 / 3))"}], "combat_messages": %{"fail": [], "other": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 55,
      #                                              (: finala, me, target :))", "= CYN "$n" CYN "见$N" CYN "掌出如风，心知"
      #                          "此招后着极是凌厉，当即斜跳闪开。\n" NOR", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 70,
      #                                              (: finalb, me, target :))", "= CYN "$n" CYN "忽闻呼啸声大至，眼见$N" CYN
      #                          "掌势如虹，急忙纵跃躲避开来。\n" NOR"], "success": ["HIW "$N" HIW "施出铁掌绝技「" HIR "阴阳磨"
      #                 HIW "」，左掌不着半点力道，携着阴寒劲向$n"
      #                 HIW "拂去。\n" NOR", "= HIR "\n紧接着$N" HIR "右掌一振，掌风过处，竟席"
      #                  "卷起一股热浪，向$n" HIR "胸前猛然拍落。\n" NOR"]}, "damage_formula": %{"formula": "ap / 2 + random(ap / 2)"}, "do_damage_calls": [%{"attack_type": "UNARMED_ATTACK", "callback": "finala", "damage_factor": 55, "damage_var": "damage"}, %{"attack_type": "UNARMED_ATTACK", "callback": "finalb", "damage_factor": 70, "damage_var": "damage"}], "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-400"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-400"}], "affect_by": ["tiezhang_yang", "tiezhang_yin"], "apply_adds": [], "busy_lines": ["me->start_busy(3 + random(3));"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3 + random(3));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define YIN "「" HIR "阴阳磨" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # string finala(object me, object target, int damage);
      # string finalb(object me, object target, int damage);
      # 
      # int perform(object me, object target)
      # {
      #         string msg;
      #         int ap, dp, dd;
      #         int damage;
      # 
      #         float improve;
      #         int lvl, i, n;
      #         string martial;
      #         string *ks;
      #         martial = "strike";
      # 
      #         if (userp(me) && ! me->query("can_perform/tie-zhang/yin"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(YIN "只能对战斗中的对手使用。\n");
      # 
      #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
      #                 return notify_fail(YIN "只能空手施展。\n");
      # 
      #         if ((int)me->query_skill("tie-zhang", 1) < 220)
      #                 return notify_fail("你铁掌掌法火候不够，难以施展" YIN "。\n");
      # 
      #         if (me->query_skill_mapped("strike") != "tie-zhang")
      #                 return notify_fail("你没有激发铁掌掌法，难以施展" YIN "。\n");
      # 
      #         if (me->query_skill_prepared("strike") != "tie-zhang")
      #                 return notify_fail("你没有准备铁掌掌法，难以施展" YIN "。\n");
      # 
      #         if ((int)me->query_skill("force") < 300)
      #                 return notify_fail("你的内功修为不够，难以施展" YIN "。\n");
      # 
      #         if ((int)me->query("max_neili") < 3500)
      #                 return notify_fail("你的内力修为不够，难以施展" YIN "。\n");
      # 
      #         if ((int)me->query("neili") < 500)
      #                 return notify_fail("你现在的真气不足，难以施展" YIN "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIW "$N" HIW "施出铁掌绝技「" HIR "阴阳磨"
      #               HIW "」，左掌不着半点力道，携着阴寒劲向$n"
      #               HIW "拂去。\n" NOR;
      # 
      #         ap = me->query_skill("strike") + me->query("str") * 5;
      #         dp = target->query_skill("parry") + target->query("con") * 5;
      #         dd = target->query_skill("dodge") + target->query("dex") * 5;
      # 
      #         lvl = to_int(pow(to_float(me->query("combat_exp") * 10), 1.0 / 3));
      #         lvl = lvl * 4 / 5;
      #         ks = keys(me->query_skills(martial));
      #         improve = 0;
      #         n = 0;
      #         //最多给予5个技能的加成
      #         for (i = 0; i < sizeof(ks); i++)
      #         {
      #             if (SKILL_D(ks[i])->valid_enable(martial))
      #             {
      #                 n += 1;
      #                 improve += (int)me->query_skill(ks[i], 1);
      #                 if (n > 4 )
      #                     break;
      #             }
      #         }
      # 
      #         improve = improve * 4 / 100 / lvl;
      # 
      #         ap += ap * improve;
      # 
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 damage = ap / 2 + random(ap / 2);
      #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 55,
      #                                            (: finala, me, target :));
      #         } else
      #         {
      #                 msg += CYN "$n" CYN "见$N" CYN "掌出如风，心知"
      #                        "此招后着极是凌厉，当即斜跳闪开。\n" NOR;
      #         }
      # 
      #         msg += HIR "\n紧接着$N" HIR "右掌一振，掌风过处，竟席"
      #                "卷起一股热浪，向$n" HIR "胸前猛然拍落。\n" NOR;
      # 
      #         if (ap / 2 + random(ap) > dd)
      #         {
      #                 damage = ap / 2 + random(ap / 2);
      #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 70,
      #                                            (: finalb, me, target :));
      #         } else
      #         {
      #                 msg += CYN "$n" CYN "忽闻呼啸声大至，眼见$N" CYN
      #                        "掌势如虹，急忙纵跃躲避开来。\n" NOR;
      #         }
      #         me->start_busy(3 + random(3));
      #         me->add("neili", -400);
      #         message_combatd(msg, me, target);
      #         return 1;
      # }
      # 
      # string finala(object me, object target, int damage)
      # {
      #         int lvl;
      #         lvl = me->query_skill("strike");
      # 
      #         target->affect_by("tiezhang_yin",
      #                        ([ "level" : me->query("jiali") + random(me->query("jiali") / 2),
      #                           "id"    : me->query("id"),
      #                           "duration" : lvl / 50 + random(lvl / 50) ]));
      # 
      #         return HIW "霎那间$n" HIW "已被$N" HIW "阴寒掌劲拂中要"
      #                "害，不由得浑身一颤，难受之极。\n" NOR;
      # }
      # 
      # string finalb(object me, object target, int damage)
      # {
      #         int lvl;
      #         lvl = me->query_skill("strike");
      # 
      #         target->affect_by("tiezhang_yang",
      #                        ([ "level" : me->query("jiali") + random(me->query("jiali") / 2),
      #                           "id"    : me->query("id"),
      #                           "duration" : lvl / 50 + random(lvl / 50) ]));
      # 
      #         return HIR "只听嗤的一声，$N" HIR "右掌如击败革，正中"
      #                "$n" HIR "胸口，震断了数根肋骨。\n" NOR;
      # }
end
