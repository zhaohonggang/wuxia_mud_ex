defmodule Kantele.Combat.Skills.Performs.YujiamuQuan.Jiang do
  @moduledoc """
  perform「修罗降世」（source yujiamu-quan/jiang.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "cuff"}, {"dp", "dodge"}, {"skill", "yujiamu-quan"}], "level_gates": [], "map_gates": [{"cuff", "yujiamu-quan"}], "prepared_gates": [{"cuff", "yujiamu-quan"}], "resource_gates": [{"neili", "180"}], "var_gates": [{"dp", "1"}, {"skill", "100"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你金刚瑜迦母拳修为不够，难以施展", "你没有激发金刚瑜迦母拳，难以施展", "你没有准备金刚瑜迦母拳，难以施展", "你目前的真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("cuff", 1) / 2 + skill", "dp_formula": "1"}, "color_codes": ["CYN", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["= CYN "可是$p" CYN "并未被这气势所慑，轻移"
      #                          "脚步，躲开了$P" CYN "的攻击。\n" NOR"], "success": ["HIR "$N" HIR "目睚俱裂，一声爆喝，全身骨骼劈啪作响，拳"
      #                         "头如闪电般击向$n" HIR "的要害！\n" NOR", "HIR "$N" HIR "大喝一声，面色赤红，全身骨骼劈啪作响，拳"
      #                         "头如闪电般击向$n" HIR "的要害！\n" NOR", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 35,
      #                                              HIR "结果$p" HIR "无法抵挡$P" HIR "这雷"
      #                                              "霆一击，登时被打退数步，摇晃不定。\n" NOR)"]}, "damage_formula": %{"formula": "10 + skill / 3 + random(skill / 2)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap * 4 / 5)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}, {"neili", "-40"}], "resource_queries": ["max_qi", "neili", "qi"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-40"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(1);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1);
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define JIANG "「" HIR "修罗降世" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         int angry;
      #         string msg;
      #         int skill, ap, dp, damage;
      # 
      #         if (userp(me) && ! me->query("can_perform/yujiamu-quan/jiang"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target)
      #         {
      #                 me->clean_up_enemy();
      #                 target = me->select_opponent();
      #         }
      # 
      #         if (! me->is_fighting(target))
      #                 return notify_fail(JIANG "只能对战斗中的对手使用。\n");
      # 
      #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
      #                 return notify_fail(JIANG "只能空手施展。\n");
      # 
      #         skill = me->query_skill("yujiamu-quan", 1);
      # 
      #         if (skill < 100)
      #                 return notify_fail("你金刚瑜迦母拳修为不够，难以施展" JIANG "。\n");
      # 
      #         if (me->query_skill_mapped("cuff") != "yujiamu-quan")
      #                 return notify_fail("你没有激发金刚瑜迦母拳，难以施展" JIANG "。\n");
      # 
      #         if (me->query_skill_prepared("cuff") != "yujiamu-quan")
      #                 return notify_fail("你没有准备金刚瑜迦母拳，难以施展" JIANG "。\n");
      # 
      #         if (me->query("neili") < 180)
      #                 return notify_fail("你目前的真气不足，难以施展" JIANG "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         if (angry = me->query("qi") < me->query("max_qi") / 2)
      #                 msg = HIR "$N" HIR "目睚俱裂，一声爆喝，全身骨骼劈啪作响，拳"
      #                       "头如闪电般击向$n" HIR "的要害！\n" NOR;
      #         else
      #                 msg = HIR "$N" HIR "大喝一声，面色赤红，全身骨骼劈啪作响，拳"
      #                       "头如闪电般击向$n" HIR "的要害！\n" NOR;
      # 
      #         ap = me->query_skill("cuff", 1) / 2 + skill;
      #         dp = target->query_skill("dodge");
      #         if (dp < 1) dp = 1;
      #         if (ap / 2 + random(ap * 4 / 5) > dp)
      #         {
      #                 me->add("neili", -100);
      #                 me->start_busy(1);
      #                 damage = 10 + skill / 3 + random(skill / 2);
      #                 if (angry) damage += random(damage / 2);
      #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 35,
      #                                            HIR "结果$p" HIR "无法抵挡$P" HIR "这雷"
      #                                            "霆一击，登时被打退数步，摇晃不定。\n" NOR);
      #         } else
      #         {
      #                 me->add("neili",-40);
      #                 msg += CYN "可是$p" CYN "并未被这气势所慑，轻移"
      #                        "脚步，躲开了$P" CYN "的攻击。\n" NOR;
      #                 me->start_busy(3);
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
end
