defmodule Kantele.Combat.Skills.Performs.RulaiZhang.Zong do
  @moduledoc """
  perform「万佛朝宗」（source rulai-zhang/zong.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "strike"}, {"dp", "parry"}], "level_gates": [{"force", "280"}, {"rulai-zhang", "150"}], "map_gates": [{"force", "hunyuan-yiqi"}], "prepared_gates": [{"strike", "rulai-zhang"}], "resource_gates": [{"max_neili", "3000"}, {"neili", "500"}], "var_gates": [{"i", "6"}, {"i", "9"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的内力修为不够，难以施展", "你的内功火候不足，难以施展", "你千手如来掌火候不够，难以施展", "你现在没有激发心意气内功为内功，难以施展", "你没有准备千手如来掌，难以施展", "你现在的真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("strike") + me->query("str") * 10", "dp_formula": "target->query_skill("parry") + target->query("dex") * 10"}, "color_codes": ["HIC", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "\n$N" HIY "当下更不耽搁，高呼佛号，轻飘飘拍出一掌，招式"
      #                 "甚为寻常。但掌到中途，忽然微微摇晃，登时一掌变两掌，两掌变四"
      #                 "掌，四掌变八掌！铺天盖地拍向$n" HIY "。" NOR", "= HIC "\n$n" HIC "见掌势层层叠叠，有如海潮，连忙"
      #                          "振作精神，勉强抵挡。\n" NOR"], "success": ["= HIY "随即又听$N" HIY "高声喝道：「" HIR "我佛如来" HIY
      #                                  "」顷刻间，但见$N" HIY "八掌又变为十六掌，进而再幻化为"
      #                                  "三十二掌，掌势层层叠叠，波澜壮阔，气势磅礴，荡气回肠"
      #                                  "。如海潮般向$n" HIY "涌去。\n\n" HIR "$n" HIR "面对这"
      #                                  "无穷无尽的掌势，竟然放弃了抵抗，面如死灰坐以待毙。\n" NOR", "= HIR "\n$n" HIR "见掌势层层叠叠，有如海潮，一时"
      #                                  "只觉头晕目眩，难作抵挡。\n" NOR"]}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-300"}, {"neili", "-500"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-300"}, {"neili", "-500"}], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["me->start_busy(3);", "//  if (random(5) < 2 && ! target->is_busy())", "//   target->start_busy(1);", "//  if (random(5) < 2 && ! target->is_busy())", "//          target->start_busy(1);", "me->start_busy(1 + random(6));"], "remote_damage": false, "set_flags": [{"eff_jing", "0"}, {"eff_qi", "0"}], "temp_set": []}
      #   - me->start_busy(3);
      #   - //  if (random(5) < 2 && ! target->is_busy())
      #   - //   target->start_busy(1);
      #   - //  if (random(5) < 2 && ! target->is_busy())
      #   - //          target->start_busy(1);
      #   - me->start_busy(1 + random(6));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
