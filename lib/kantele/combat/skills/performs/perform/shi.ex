defmodule Kantele.Combat.Skills.Performs.Perform.Shi do
  @moduledoc """
  perform「噬血穹苍」（source perform/shi.c，由 translate_perform.exs 骨架生成，inherit F_SSERVER）

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
      #   %{
      #     assign_refs: [{"ap", "blade"}, {"count", "xuedao-dafa"}, {"dp", "dodge"}],
      #     level_gates: [{"force", "250"}, {"xuedao-dafa", "180"}],
      #     map_gates: [{"blade", "xuedao-dafa"}, {"force", "xuedao-dafa"}],
      #     prepared_gates: [],
      #     resource_gates: [{"neili", "500"}, {"qi", "100"}],
      #     var_gates: [{"i", "6"}]
      #   }
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{
      #     add_costs: [],
      #     affect_by: [],
      #     apply_adds: ["attack"],
      #     busy_lines: ["if (random(3) == 1 && ! target->is_busy())",
      #      "target->start_busy(1);", "me->start_busy(2 + random(6));"],
      #     remote_damage: true,
      #     set_flags: [],
      #     temp_set: []
      #   }
      #   - if (random(3) == 1 && ! target->is_busy())
      #   - target->start_busy(1);
      #   - me->start_busy(2 + random(6));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
