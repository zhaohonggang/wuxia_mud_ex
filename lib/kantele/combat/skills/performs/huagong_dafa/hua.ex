defmodule Kantele.Combat.Skills.Performs.HuagongDafa.Hua do
  @moduledoc """
  exert「hua」（source huagong-dafa/hua.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"dp", "force"}, {"sp", "force"}], "level_gates": [{"huagong-dafa", "100"}], "map_gates": [], "prepared_gates": [], "resource_gates": [{"max_neili", "1"}, {"max_neili", "10"}, {"neili", "10"}, {"neili", "120"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["在这里不能攻击他人。\n", "你要化谁的内力？\n", "搞错了！只有人才能有内力！\n", "你现在正忙，无法化他人内力。\n", "你必须空手才能施用化功大法！\n", "你的化功大法功力不够，不能施展！\n", "你的内力不够，不能施展化功大法。\n"], "ap_dp_formulas": %{"dp_formula": "target->query_skill("force") + target->query_skill("dodge")"}, "color_codes": ["HIG", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": [], "success": []}, "resource_adds": [{"max_neili", "-1 * (random(4) + (me->query_skill("huagong-dafa", 1) - 90) / 8)"}, {"neili", "-100"}], "resource_queries": ["max_neili", "neili"], "resource_sets": [{"max_neili", "0"}], "target_logic": %{"requires_fighting": false, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (me->is_busy())", "me->start_busy(2 + random(2));", "if (! target->is_busy())target->start_busy(2);", "me->start_busy(2 + random(3));"], "remote_damage": false, "set_flags": [{"max_neili", "0"}], "temp_set": []}
      #   - if (me->is_busy())
      #   - me->start_busy(2 + random(2));
      #   - if (! target->is_busy())target->start_busy(2);
      #   - me->start_busy(2 + random(3));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
