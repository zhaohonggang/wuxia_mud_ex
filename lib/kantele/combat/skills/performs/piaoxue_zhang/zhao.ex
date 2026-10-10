defmodule Kantele.Combat.Skills.Performs.PiaoxueZhang.Zhao do
  @moduledoc """
  perform「佛光普照」（source piaoxue-zhang/zhao.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "strike"}, {"dp", "dodge"}], "level_gates": [{"force", "300"}, {"piaoxue-zhang", "180"}], "map_gates": [{"force", "emei-jiuyang"}, {"force", "jiuyang-shengong"}, {"force", "shaolin-jiuyang"}, {"force", "wudang-jiuyang"}, {"strike", "piaoxue-zhang"}], "prepared_gates": [{"strike", "piaoxue-zhang"}], "resource_gates": [{"max_neili", "3500"}, {"neili", "1000"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你必须空手才能施展", "你的内功的修为不够，无法施展", "你的飘雪穿云掌修为不够，无法施展", "你的真气不够，无法施展", "你没有激发内功为九阳神功，无法施展", "你没有激发飘雪穿云掌，无法施展", "你没有准备飘雪穿云掌，无法施展", "你必须将全身功力尽数提起才能施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("strike") +
      #                me->query_skill("force") +
      #                me->query("str") * 5", "dp_formula": "target->query_skill("dodge") +
      #                target->query_skill("force") +
      #                target->query("con") * 5"}, "color_codes": ["CYN", "HIR", "HIW", "HIY", "NOR"], "combat_messages": %{"fail": ["= CYN "可是$p" CYN "内力深厚，及时摆脱了" 
      #                          CYN "$P" CYN "内力的牵扯，躲开了这一击！\n" NOR"], "other": ["HIY "$N" HIY "运起全身功力，顿时真气迸发，全身骨骼噼啪作"
      #                 "响，猛然一掌向$n" HIY "\n全力拍出，力求一击毙敌，正是一"
      #                 "招「佛光普照」。\n" NOR", "= HIW "只听轰然一声巨响，$n" HIW "已被一招正中，可$N"
      #                          HIW "只觉全身内力犹如江河入\n海，又如水乳交融，登"
      #                          "时消失得无影无踪。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 100,
      #                                              HIR "只听轰然一声巨响，$n" HIR "被$N"
      #                                              HIR "一招正中，身子便如稻草般平平飞出"
      #                                              "，重\n重摔在地下，呕出一大口鲜血，动"
      #                                              "也不动。\n" NOR)"]}, "damage_formula": %{"formula": "random(ap / 3) + ap / 3"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-400"}, {"neili", "-600"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-400"}, {"neili", "-600"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(3);", "me->start_busy(3);", "me->start_busy(4);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3);
      #   - me->start_busy(3);
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
      # #define ZHAO "「" HIY "佛光普照" NOR "」"
      # 
      # inherit F_SSERVER; 
      #          
      # int perform(object me, object target) 
      # { 
      # //      object weapon; 
      #         string msg; 
      #         int ap, dp; 
      #         int damage; 
      # 
      #         if (userp(me) && ! me->query("can_perform/piaoxue-zhang/zhao"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me); 
      #         
      #         if (! target || ! me->is_fighting(target)) 
      #                 return notify_fail(ZHAO "只能在战斗中对对手使用。\n"); 
      #          
      #         if (me->query_temp("weapon") || 
      #             me->query_temp("secondary_weapon")) 
      #                 return notify_fail("你必须空手才能施展" ZHAO "。\n"); 
      #          
      #         if (me->query_skill("force") < 300) 
      #                 return notify_fail("你的内功的修为不够，无法施展" ZHAO "。\n"); 
      #         
      #         if (me->query_skill("piaoxue-zhang", 1) < 180) 
      #                 return notify_fail("你的飘雪穿云掌修为不够，无法施展" ZHAO "。\n"); 
      #          
      #         if (me->query("neili") < 1000 || me->query("max_neili") < 3500) 
      #                 return notify_fail("你的真气不够，无法施展" ZHAO "。\n"); 
      # 
      # /*
      #         if (me->query_skill_mapped("force") != "emei-jiuyang" &&
      #             me->query_skill_mapped("force") != "wudang-jiuyang" &&
      #             me->query_skill_mapped("force") != "shaolin-jiuyang" &&
      #             me->query_skill_mapped("force") != "jiuyang-shengong") 
      #                 return notify_fail("你没有激发内功为九阳神功，无法施展" ZHAO "。\n"); 
      # */
      # 
      #         if (me->query_skill_mapped("strike") != "piaoxue-zhang") 
      #                 return notify_fail("你没有激发飘雪穿云掌，无法施展" ZHAO "。\n"); 
      # 
      #         if (me->query_skill_prepared("strike") != "piaoxue-zhang")
      #                 return notify_fail("你没有准备飘雪穿云掌，无法施展" ZHAO "。\n"); 
      # 
      #         if (! me->query_temp("powerup"))
      #                 return notify_fail("你必须将全身功力尽数提起才能施展" ZHAO "。\n");
      # 
      #         if (! living(target))
      #                return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIY "$N" HIY "运起全身功力，顿时真气迸发，全身骨骼噼啪作"
      #               "响，猛然一掌向$n" HIY "\n全力拍出，力求一击毙敌，正是一"
      #               "招「佛光普照」。\n" NOR;
      #          
      #         ap = me->query_skill("strike") +
      #              me->query_skill("force") +
      #              me->query("str") * 5;
      # 
      #         dp = target->query_skill("dodge") +
      #              target->query_skill("force") +
      #              target->query("con") * 5;
      # 
      #         //damage = random(ap / 3) + ap / 3;
      #         damage = random(ap / 2) + ap / 2;
      # 
      #         if (target->query_skill_mapped("force") == "jiuyang-shengong")
      #         {
      #                 me->add("neili", -600);
      #                 me->start_busy(3);
      #                 msg += HIW "只听轰然一声巨响，$n" HIW "已被一招正中，可$N"
      #                        HIW "只觉全身内力犹如江河入\n海，又如水乳交融，登"
      #                        "时消失得无影无踪。\n" NOR; 
      #         } else
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 me->add("neili", -600);
      #                 me->start_busy(3);
      #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 100,
      #                                            HIR "只听轰然一声巨响，$n" HIR "被$N"
      #                                            HIR "一招正中，身子便如稻草般平平飞出"
      #                                            "，重\n重摔在地下，呕出一大口鲜血，动"
      #                                            "也不动。\n" NOR);
      #         } else 
      #         { 
      #                 me->add("neili", -400);
      #                 me->start_busy(4);
      #                 msg += CYN "可是$p" CYN "内力深厚，及时摆脱了" 
      #                        CYN "$P" CYN "内力的牵扯，躲开了这一击！\n" NOR; 
      #         }
      #         message_combatd(msg, me, target);
      #        
      #         return 1; 
      # }
end
