defmodule Kantele.Combat.Skills.Performs.ZuiGun.Zuida do
  @moduledoc """
  perform「zuida」（source zui-gun/zuida.c，由 translate_perform.exs 骨架生成，inherit F_SSERVER）

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
      #     assign_refs: [{"skill", "zui-gun"}],
      #     level_gates: [{"club", "100"}, {"force", "150"}],
      #     map_gates: [
      #       {"force", "hunyuan-yiqi"},
      #       {"force", "luohan-fumogong"},
      #       {"force", "yijinjing"}
      #     ],
      #     prepared_gates: [],
      #     resource_gates: [{"neili", "500"}],
      #     var_gates: []
      #   }
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{
      #     add_costs: [{"neili", "-150"}],
      #     affect_by: [],
      #     apply_adds: [],
      #     busy_lines: ["me->start_busy(2);"],
      #     remote_damage: false,
      #     set_flags: [],
      #     temp_set: ["zg_zuida"]
      #   }
      #   - me->start_busy(2);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
