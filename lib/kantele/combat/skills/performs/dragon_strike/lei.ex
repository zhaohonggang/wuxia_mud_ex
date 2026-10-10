defmodule Kantele.Combat.Skills.Performs.DragonStrike.Lei do
  @moduledoc """
  perform「雷霆一击」（source dragon-strike/lei.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "strike"}, {"dp", "dodge"}], "level_gates": [{"dragon-strike", "180"}, {"force", "250"}], "map_gates": [{"strike", "dragon-strike"}], "prepared_gates": [{"strike", "dragon-strike"}], "resource_gates": [{"max_neili", "2500"}, {"neili", "600"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你内功修为不够，难以施展", "你内力修为不够，难以施展", "你降龙十八掌火候不够，难以施展", "你没有激发降龙十八掌，难以施展", "你没有准备降龙十八掌，难以施展", "你现在真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("strike") + me->query("str") * 10", "dp_formula": "target->query_skill("dodge") + target->query("dex") * 10"}, "color_codes": ["HIC", "HIG", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIC "$N" HIC "默运内功，施展出" LEI + HIC "，全身急速转动起来，"
      #                 "越来越快，就\n犹如一股旋风，骤然间，$N" HIC "已卷向正看"
      #                 "得发呆的" HIC "$n。\n"NOR", "= HIG "可是$p" HIG "看破了$P" HIG "的企图，没"
      #                          "有受到迷惑，闪在了一边。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 70,
      #                                              HIR "$p" HIR "只见一阵旋风影中陡然现出$P"
      #                                              HIR "的双拳，根本来不及躲避，被重重击中，\n五"
      #                                              "脏六腑翻腾不休，口中鲜血如箭般喷出！\n" NOR)"]}, "damage_formula": %{"formula": "ap + random(ap / 2)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-400"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-400"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
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
      # #define LEI "「" HIY "雷霆一击" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         int damage;
      #         string msg;
      #         int ap, dp;
      # 
      #         if (userp(me) && ! me->query("can_perform/dragon-strike/lei"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(LEI "只能对战斗中的对手使用。\n");
      # 
      #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
      #                 return notify_fail(LEI "只能空手使用。\n");
      # 
      #         if ((int)me->query_skill("force") < 250)
      #                 return notify_fail("你内功修为不够，难以施展" LEI "。\n");
      # 
      #         if ((int)me->query("max_neili") < 2500)
      #                 return notify_fail("你内力修为不够，难以施展" LEI "。\n");
      # 
      #         if ((int)me->query_skill("dragon-strike", 1) < 180)
      #                 return notify_fail("你降龙十八掌火候不够，难以施展" LEI "。\n");
      # 
      #         if (me->query_skill_mapped("strike") != "dragon-strike")
      #                 return notify_fail("你没有激发降龙十八掌，难以施展" LEI "。\n");
      # 
      #         if (me->query_skill_prepared("strike") != "dragon-strike")
      #                 return notify_fail("你没有准备降龙十八掌，难以施展" LEI "。\n");
      # 
      #         if ((int)me->query("neili") < 600)
      #                 return notify_fail("你现在真气不够，难以施展" LEI "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIC "$N" HIC "默运内功，施展出" LEI + HIC "，全身急速转动起来，"
      #               "越来越快，就\n犹如一股旋风，骤然间，$N" HIC "已卷向正看"
      #               "得发呆的" HIC "$n。\n"NOR;  
      # 
      #         ap = me->query_skill("strike") + me->query("str") * 10;
      #         dp = target->query_skill("dodge") + target->query("dex") * 10;
      #         me->start_busy(3);
      #         if (ap / 2 + random(ap) > dp)
      #         { 
      #                 damage = ap + random(ap / 2);
      #                 me->add("neili", -400);
      #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 70,
      #                                            HIR "$p" HIR "只见一阵旋风影中陡然现出$P"
      #                                            HIR "的双拳，根本来不及躲避，被重重击中，\n五"
      #                                            "脏六腑翻腾不休，口中鲜血如箭般喷出！\n" NOR);
      #         } else
      #         {
      #                 msg += HIG "可是$p" HIG "看破了$P" HIG "的企图，没"
      #                        "有受到迷惑，闪在了一边。\n" NOR;
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
end
