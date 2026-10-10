defmodule Kantele.Combat.Skills.Performs.QixingShou.Po do
  @moduledoc """
  perform「破穹」（source qixing-shou/po.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "hand"}, {"damage", "qixing-shou"}, {"dp", "dodge"}, {"dp", "force"}, {"dp", "parry"}], "level_gates": [{"force", "200"}, {"qixing-shou", "150"}], "map_gates": [{"hand", "qixing-shou"}], "prepared_gates": [{"hand", "qixing-shou"}], "resource_gates": [{"neili", "300"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "只有空手才能施展", "你七星分天手不够娴熟，难以施展", "你没有激发七星分天手，难以施展", "你没有准备七星分天手，难以施展", "你的内功修为不够，难以施展", "你现在的真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("hand")", "dp_formula": "target->query_skill("force")"}, "color_codes": ["CYN", "HIC", "HIR", "HIW", "HIY", "MAG", "NOR"], "combat_messages": %{"fail": [], "other": ["HIC "$N" HIC "双目圆睁，单手陡然一振，袖底顿时窜出一道" NOR + MAG
      #                 "紫光" HIC "，直射$n" HIC "前胸。\n" NOR", "= CYN "$p" CYN "见势不妙，急忙向后纵开数尺，避开了$P"
      #                          CYN "这招。\n" NOR", "= "\n" HIC "紧接着$N" HIC "左掌蓦的一抬，凭空虚划了道" HIY "弧芒" HIC
      #                  "，至上而下反推$n" HIC "后颈。\n" NOR", "= CYN "可是$p" CYN "丝毫不为$P"
      #                          CYN "所动，奋力格挡，稳稳将这一招架开。\n" NOR", "= "\n" HIC "便在此时，却见$N" HIC "双掌猛然回圈，平推而出，顿时层层"
      #                  HIW "气浪" HIC "直袭$n" HIC "。\n" NOR", "= CYN "然而$p" CYN "沉身聚气，奋力一格，便将$P"
      #                          CYN "这掌驱于无形。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 20,
      #                                              HIR "但见$P" HIR "这道气劲来势迅猛之极"
      #                                              "，$n" HIR "如何避得，顿时被紫劲震开了"
      #                                              "数尺！\n" NOR)", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 25,
      #                                              HIR "$p" HIR "只觉后颈一麻，已被$N" HIR
      #                                              "这招击个正中，顿时全身瘫软，呕出一口鲜"
      #                                              "血！\n" NOR)", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 30,
      #                                              HIR "$p" HIR "在$N" HIR "的猛攻之下，已"
      #                                              "再无余力招架，竟被这一掌震得飞起，摔了"
      #                                              "出去！\n" NOR)"]}, "damage_formula": %{"formula": "(int)me->query_skill("qixing-shou", 1) / 2"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-200"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-200"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2 + random(3));"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2 + random(3));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
