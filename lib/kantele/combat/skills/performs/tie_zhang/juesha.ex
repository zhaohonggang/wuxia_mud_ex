defmodule Kantele.Combat.Skills.Performs.TieZhang.Juesha do
  @moduledoc """
  perform「juesha」（source tie-zhang/juesha.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "strike"}, {"dp", "parry"}], "level_gates": [{"force", "300"}, {"tie-zhang", "200"}], "map_gates": [{"force", "tianlei-shengong"}, {"strike", "tie-zhang"}], "prepared_gates": [{"strike", "tie-zhang"}], "resource_gates": [{"max_neili", "2200"}, {"neili", "500"}], "var_gates": [{"i", "6"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "「九穹绝刹掌」只能在战斗中对对手使用。\n", "「九穹绝刹掌」只能空手使用。\n", "你的内力修为还不够，无法施展「九穹绝刹掌」。\n", "你的真气不够！\n", "你的铁掌火候不够，无法使用「九穹绝刹掌」！\n", "你的内功修为不够，无法使用「九穹绝刹掌」！\n", "你没有激发铁掌掌法，难以施展「九穹绝刹掌」。\n", "你现在没有准备使用铁掌掌法，难以施展「九穹绝刹掌」。\n", "施展「九穹绝刹掌」时铁掌掌法不宜和铁线拳互背！\n", "你必须激发天雷神功才能施展出「九穹绝刹掌」！\n", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("strike") + me->query("str") * 10", "dp_formula": "target->query_skill("parry") + target->query("dex") * 6"}, "color_codes": ["HIC", "HIR", "NOR", "RED", "WHT"], "combat_messages": %{"fail": [], "other": ["= RED "$n" RED "面对$P" RED "这排山倒海攻势，完全"
      #                          "无法抵挡，唯有退后。\n" NOR", "= HIC "$n" HIC "凝神应战，竭尽所能化解$P" HIC "这"
      #                          "几掌。\n" NOR"], "success": ["HIR "$N" HIR "一声怒喝，猛然施出铁掌掌法绝技「" NOR + WHT 
      #                 "九穹绝刹掌" NOR + HIR "」！体内天雷真气急速运转，双臂陡"
      #                 "然\n暴长数尺。只听破空之声骤响，双掌幻出漫天掌影，铺天"
      #                 "盖地向$n" HIR "连环拍出！\n\n" NOR"]}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-300"}, {"qi", "-100"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
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
      #         if (userp(me) && ! me->query("can_perform/tie-zhang/juesha"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail("「九穹绝刹掌」只能在战斗中对对手使用。\n");
      #  
      #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
      #                 return notify_fail("「九穹绝刹掌」只能空手使用。\n");
      #                 
      #         if (me->query("max_neili") < 2200)
      #                 return notify_fail("你的内力修为还不够，无法施展「九穹绝刹掌」。\n");
      # 
      #         if ((int)me->query("neili") < 500)
      #                 return notify_fail("你的真气不够！\n");
      # 
      #         if ((int)me->query_skill("tie-zhang", 1) < 200)
      #                 return notify_fail("你的铁掌火候不够，无法使用「九穹绝刹掌」！\n");
      # 
      #         if ((int)me->query_skill("force") < 300)
      #                 return notify_fail("你的内功修为不够，无法使用「九穹绝刹掌」！\n");
      # 
      #         if (me->query_skill_mapped("strike") != "tie-zhang")
      #                 return notify_fail("你没有激发铁掌掌法，难以施展「九穹绝刹掌」。\n");
      # 
      #         if (me->query_skill_prepared("strike") != "tie-zhang")
      #                 return notify_fail("你现在没有准备使用铁掌掌法，难以施展「九穹绝刹掌」。\n");
      # 
      #         if (me->query_skill_prepared("cuff") == "tiexian-quan"
      #             || me->query_skill_prepared("unarmed") == "tiexian-quan" )
      #                 return notify_fail("施展「九穹绝刹掌」时铁掌掌法不宜和铁线拳互背！\n");
      # 
      #         if ((string)me->query_skill_mapped("force") != "tianlei-shengong")
      #                 return notify_fail("你必须激发天雷神功才能施展出「九穹绝刹掌」！\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIR "$N" HIR "一声怒喝，猛然施出铁掌掌法绝技「" NOR + WHT 
      #               "九穹绝刹掌" NOR + HIR "」！体内天雷真气急速运转，双臂陡"
      #               "然\n暴长数尺。只听破空之声骤响，双掌幻出漫天掌影，铺天"
      #               "盖地向$n" HIR "连环拍出！\n\n" NOR;
      #         ap = me->query_skill("strike") + me->query("str") * 10;
      #         dp = target->query_skill("parry") + target->query("dex") * 6;
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 count = ap / 9;
      #                 msg += RED "$n" RED "面对$P" RED "这排山倒海攻势，完全"
      #                        "无法抵挡，唯有退后。\n" NOR;
      #         } else
      #         {
      #                 msg += HIC "$n" HIC "凝神应战，竭尽所能化解$P" HIC "这"
      #                        "几掌。\n" NOR;
      #                 count = 0;
      #         }
      # 
      #         message_vision(msg, me, target);
      #         me->add_temp("apply/attack", count);
      # 
      #         me->add("neili", -300);
      #         me->add("qi", -100);    // Why I don't use receive_damage ?
      #                                 // Becuase now I was use it as a cost
      #         for (i = 0; i < 6; i++)
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
