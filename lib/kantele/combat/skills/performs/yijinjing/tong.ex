defmodule Kantele.Combat.Skills.Performs.Yijinjing.Tong do
  @moduledoc """
  exert「tong」（source yijinjing/tong.c，由 translate_perform.py 骨架生成，inherit F_CLEAN_UP）

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
      #   %{"assign_refs": [{"skill", "yijinjing"}], "level_gates": [{"yijinjing", "100"}], "map_gates": [], "prepared_gates": [], "resource_gates": [{"max_neili", "500"}, {"max_qi", "10"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你不是少林弟子，无法使用“易筋通脉”。\n", "你所学的内功中没有这种功能。\n", "你只能用易筋经来为自己易筋通脉。 \n", "你的易筋经等级不够。\n", "你伤势很轻，不用激励易筋经至高绝学。\n", "你内伤太重，无法激励易筋经至高绝学。\n", "你的真气不够。\n"], "color_codes": ["HIC", "HIM", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": [], "success": []}, "receive_damage_calls": [%{"formula": "0", "kind": "damage", "part": "qi", "source": None}], "resource_adds": [{"max_neili", "-skill/4"}, {"neili", "-skill*4"}], "resource_queries": ["max_neili", "max_qi", "neili"], "resource_sets": [{"qi", "me->query("eff_qi")"}], "target_logic": %{"requires_fighting": true, "requires_living": false, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": [], "apply_adds": [], "busy_lines": ["if (me->is_fighting()) me->start_busy(4);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (me->is_fighting()) me->start_busy(4);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
