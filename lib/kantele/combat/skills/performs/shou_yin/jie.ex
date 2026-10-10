defmodule Kantele.Combat.Skills.Performs.ShouYin.Jie do
  @moduledoc """
  perform「jie」（source shou-yin/jie.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "strike"}, {"dp", "parry"}], "level_gates": [{"force", "300"}, {"shou-yin", "150"}], "map_gates": [], "prepared_gates": [{"hand", "shou-yin"}], "resource_gates": [{"max_neili", "3000"}, {"neili", "500"}, {"qi", "800"}], "var_gates": [{"i", "9"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["「天劫」只能在战斗中对对手使用。\n", "「天劫」只能空手使用。\n", "你的内力修为还不够，无法施展天劫。\n", "你的真气不够！\n", "你的体力现在不够！\n", "你的手印火候不够，无法使用天劫！\n", "你的内功修为不够，无法使用天劫！\n", "你现在没有准备使用手印，无法使用天劫！\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("strike") + me->query("str") * 10", "dp_formula": "target->query_skill("parry") + target->query("dex") * 6"}, "color_codes": ["HIC", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "$N" HIW "一声暴喝，双手猛然翻滚，"
      #                 "刹那间只见无数的手印铺天盖地蜂拥而出，"
      #                 "气势恢弘，无与伦比。\n" NOR", "= HIC "$n" HIC "凝神应战，竭尽所能化解$P" HIC
      #                          "这几掌。\n" NOR"], "success": ["= HIR "$n" HIR "面对$P" HIR "这排山倒海攻势，完全"
      #                          "无法抵挡，唯有退后。\n" NOR"]}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-300"}, {"qi", "-100"}], "resource_queries": ["max_neili", "neili", "qi"], "target_logic": %{"requires_fighting": true, "requires_living": false, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-300"}, {"qi", "-100"}], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["if (random(5) < 2 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(5));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (random(5) < 2 && ! target->is_busy())
      #   - target->start_busy(1);
      #   - me->start_busy(1 + random(5));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // jie.c 天劫
      # 
      # #include <ansi.h>
      # 
      # inherit F_SSERVER;
      #  
      # int perform(object me, object target)
      # {
      #         string msg;
      #         int ap, dp;
      #         int count;
      #         int i;
      #  
      #         if (! target)
      #         {
      #                 me->clean_up_enemy();
      #                 target = me->select_opponent();
      #         }
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail("「天劫」只能在战斗中对对手使用。\n");
      #  
      #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
      #                 return notify_fail("「天劫」只能空手使用。\n");
      #                 
      #         if (me->query("max_neili") < 3000)
      #                 return notify_fail("你的内力修为还不够，无法施展天劫。\n");
      # 
      #         if ((int)me->query("neili") < 500)
      #                 return notify_fail("你的真气不够！\n");
      # 
      #         if ((int)me->query("qi") < 800)
      #                 return notify_fail("你的体力现在不够！\n");
      # 
      #         if ((int)me->query_skill("shou-yin", 1) < 150)
      #                 return notify_fail("你的手印火候不够，无法使用天劫！\n");
      # 
      #         if ((int)me->query_skill("force") < 300)
      #                 return notify_fail("你的内功修为不够，无法使用天劫！\n");
      # 
      #         if (me->query_skill_prepared("hand") != "shou-yin")
      #                 return notify_fail("你现在没有准备使用手印，无法使用天劫！\n");
      # 
      #         msg = HIW "$N" HIW "一声暴喝，双手猛然翻滚，"
      #               "刹那间只见无数的手印铺天盖地蜂拥而出，"
      #               "气势恢弘，无与伦比。\n" NOR;
      #         ap = me->query_skill("strike") + me->query("str") * 10;
      #         dp = target->query_skill("parry") + target->query("dex") * 6;
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 count = ap / 9;
      #                 msg += HIR "$n" HIR "面对$P" HIR "这排山倒海攻势，完全"
      #                        "无法抵挡，唯有退后。\n" NOR;
      #         } else
      #         {
      #                 msg += HIC "$n" HIC "凝神应战，竭尽所能化解$P" HIC
      #                        "这几掌。\n" NOR;
      #                 count = 0;
      #         }
      # 
      #         message_vision(msg, me, target);
      #         me->add_temp("apply/attack", count);
      # 
      #         me->add("neili", -300);
      #         me->add("qi", -100);    // Why I don't use receive_damage ?
      #                                 // Becuase now I was use it as a cost
      #         for (i = 0; i < 9; i++)
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
