defmodule Kantele.Combat.Skills.Performs.XuantianZhi.Bing do
  @moduledoc """
  perform「冰坚地狱」（source xuantian-zhi/bing.c，由 translate_perform.exs 骨架生成，inherit F_SSERVER）

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
      #     assign_refs: [{"ap", "finger"}, {"dp", "force"}, {"lvl", "xuantian-zhi"}],
      #     level_gates: [{"xuantian-wujigong", "180"}, {"xuantian-zhi", "180"}],
      #     map_gates: [{"finger", "xuantian-zhi"}],
      #     prepared_gates: [{"finger", "xuantian-zhi"}],
      #     resource_gates: [{"max_neili", "2000"}, {"neili", "500"}],
      #     var_gates: []
      #   }
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{
      #     add_costs: [{"neili", "-400"}],
      #     affect_by: ["xuantian_zhi"],
      #     apply_adds: [],
      #     busy_lines: ["me->start_busy(4);"],
      #     remote_damage: true,
      #     set_flags: [],
      #     temp_set: []
      #   }
      #   - me->start_busy(4);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
