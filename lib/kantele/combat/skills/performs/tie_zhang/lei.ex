defmodule Kantele.Combat.Skills.Performs.TieZhang.Lei do
  @moduledoc """
  perform「掌心雷」（source tie-zhang/lei.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "strike"}, {"dp", "parry"}], "level_gates": [{"force", "220"}, {"tie-zhang", "160"}], "map_gates": [{"strike", "tie-zhang"}], "prepared_gates": [{"strike", "tie-zhang"}], "resource_gates": [{"max_neili", "2200"}, {"neili", "300"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你铁掌掌法火候不够，难以施展", "你没有激发铁掌掌法，难以施展", "你没有准备铁掌掌法，难以施展", "你的内功修为不够，难以施展", "你的内力修为不够，难以施展", "你现在的真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("strike") + me->query("str") * 8", "dp_formula": "target->query_skill("parry") + target->query("con") * 8"}, "color_codes": ["CYN", "HIR", "NOR", "WHT"], "combat_messages": %{"fail": [], "other": ["= CYN "$n" CYN "眼见$N" CYN "来势汹涌，丝毫"
      #                          "不敢小觑，急忙闪在了一旁。\n" NOR"], "success": ["WHT "$N" WHT "运转真气施出「" HIR "掌心雷" NOR +
      #                 WHT "」绝技，双掌翻红，有如火烧，朝$n" WHT "猛"
      #                 "然拍出。\n" NOR", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 65,
      #                                              HIR "结果只听$n" HIR "一声闷哼，被$N"
      #                                              HIR "一掌劈个正着，口中鲜血狂喷而出。"
      #                                              "\n" NOR)"]}, "damage_formula": %{"formula": "ap + random(ap / 2)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}, {"neili", "-250"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-250"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(3);", "me->start_busy(4);"], "remote_damage": true, "set_flags": [], "temp_set": []}
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
      # #define LEI "「" HIR "掌心雷" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         string msg;
      #         int ap, dp;
      #         int damage;
      # 
      #         if (userp(me) && ! me->query("can_perform/tie-zhang/lei"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(LEI "只能对战斗中的对手使用。\n");
      # 
      #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
      #                 return notify_fail(LEI "只能空手施展。\n");
      # 
      #         if ((int)me->query_skill("tie-zhang", 1) < 160)
      #                 return notify_fail("你铁掌掌法火候不够，难以施展" LEI "。\n");
      # 
      #         if (me->query_skill_mapped("strike") != "tie-zhang")
      #                 return notify_fail("你没有激发铁掌掌法，难以施展" LEI "。\n");
      # 
      #         if (me->query_skill_prepared("strike") != "tie-zhang")
      #                 return notify_fail("你没有准备铁掌掌法，难以施展" LEI "。\n");
      # 
      #         if ((int)me->query_skill("force") < 220)
      #                 return notify_fail("你的内功修为不够，难以施展" LEI "。\n");
      # 
      #         if ((int)me->query("max_neili") < 2200)
      #                 return notify_fail("你的内力修为不够，难以施展" LEI "。\n");
      # 
      #         if ((int)me->query("neili") < 300)
      #                 return notify_fail("你现在的真气不足，难以施展" LEI "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = WHT "$N" WHT "运转真气施出「" HIR "掌心雷" NOR +
      #               WHT "」绝技，双掌翻红，有如火烧，朝$n" WHT "猛"
      #               "然拍出。\n" NOR;
      # 
      #         ap = me->query_skill("strike") + me->query("str") * 8;
      #         dp = target->query_skill("parry") + target->query("con") * 8;
      # 
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 damage = ap + random(ap / 2);
      #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 65,
      #                                            HIR "结果只听$n" HIR "一声闷哼，被$N"
      #                                            HIR "一掌劈个正着，口中鲜血狂喷而出。"
      #                                            "\n" NOR);
      #                 me->add("neili", -250);
      #                 me->start_busy(3);
      #         } else
      #         {
      #                 msg += CYN "$n" CYN "眼见$N" CYN "来势汹涌，丝毫"
      #                        "不敢小觑，急忙闪在了一旁。\n" NOR;
      #                 me->add("neili", -100);
      #                 me->start_busy(4);
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
end
