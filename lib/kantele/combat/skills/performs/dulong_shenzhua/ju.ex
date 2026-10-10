defmodule Kantele.Combat.Skills.Performs.DulongShenzhua.Ju do
  @moduledoc """
  perform「真龙聚」（source dulong-shenzhua/ju.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "claw"}, {"dp", "parry"}], "level_gates": [{"dulong-shenzhua", "130"}, {"force", "180"}], "map_gates": [{"claw", "dulong-shenzhua"}], "prepared_gates": [{"claw", "dulong-shenzhua"}], "resource_gates": [{"neili", "300"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你毒龙神爪功不够娴熟，难以施展", "你没有激发毒龙神爪功，难以施展", "你没有准备毒龙神爪功，难以施展", "你的内功修为不够，难以施展", "你现在的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("claw") + me->query_skill("force")", "dp_formula": "target->query_skill("parry") + target->query_skill("force")"}, "color_codes": ["CYN", "HIC", "HIM", "HIR", "NOR"], "combat_messages": %{"fail": ["= CYN "$n" CYN "奋力招架，竟将$N" CYN "这招化解。\n" NOR"], "other": ["HIC "\n$N" HIC "运转真气，将体内真气积聚于双爪间，猛然间双爪凌"
      #                 "空而下，犹如神龙般划向$n" HIC "，这招正是玄冥谷绝学「" HIM "真"
      #                 "龙聚" HIC "」。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 65,
      #                                              HIR "但见$N" HIR "双爪划过，$n" HIR "已闪避不及，胸口被$N" HIR
      #                                              "抓出十条血痕。\n" NOR)"]}, "damage_formula": %{"formula": "ap + random(ap / 2)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}, {"neili", "-220"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-220"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(3);", "me->start_busy(4);"], "remote_damage": true, "set_flags": [], "temp_set": []}
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
      # #define JU "「" HIM "真龙聚" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         int damage;
      #         string msg;
      #         int ap, dp;
      # 
      #         if (userp(me) && ! me->query("can_perform/dulong-shenzhua/ju"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(JU "只能对战斗中的对手使用。\n");
      # 
      #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
      #                 return notify_fail(JU "只能空手施展。\n");
      # 
      #         if ((int)me->query_skill("dulong-shenzhua", 1) < 130)
      #                 return notify_fail("你毒龙神爪功不够娴熟，难以施展" JU "。\n");
      # 
      #         if (me->query_skill_mapped("claw") != "dulong-shenzhua")
      #                 return notify_fail("你没有激发毒龙神爪功，难以施展" JU "。\n");
      # 
      #         if (me->query_skill_prepared("claw") != "dulong-shenzhua")
      #                 return notify_fail("你没有准备毒龙神爪功，难以施展" JU "。\n");
      # 
      #         if (me->query_skill("force") < 180)
      #                 return notify_fail("你的内功修为不够，难以施展" JU "。\n");
      # 
      #         if ((int)me->query("neili") < 300)
      #                 return notify_fail("你现在的真气不够，难以施展" JU "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         ap = me->query_skill("claw") + me->query_skill("force");
      #         dp = target->query_skill("parry") + target->query_skill("force");
      # 
      #         msg = HIC "\n$N" HIC "运转真气，将体内真气积聚于双爪间，猛然间双爪凌"
      #               "空而下，犹如神龙般划向$n" HIC "，这招正是玄冥谷绝学「" HIM "真"
      #               "龙聚" HIC "」。\n" NOR;
      # 
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 damage = ap + random(ap / 2);
      #                 
      #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 65,
      #                                            HIR "但见$N" HIR "双爪划过，$n" HIR "已闪避不及，胸口被$N" HIR
      #                                            "抓出十条血痕。\n" NOR);
      # 
      #                 me->start_busy(3);
      #                 me->add("neili", -220);
      #         } else
      #         {
      #                 msg += CYN "$n" CYN "奋力招架，竟将$N" CYN "这招化解。\n" NOR;
      # 
      #                 me->start_busy(4);
      #                 me->add("neili", -100);
      #         }
      #         message_sort(msg, me, target);
      #         return 1;
      # }
end
