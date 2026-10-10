defmodule Kantele.Combat.Skills.Performs.Perform.Jian do
  @moduledoc """
  perform「先天功」（source perform/jian.c，由 translate_perform.exs 骨架生成，inherit F_SSERVER）

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
      #     assign_refs: [{"ap", "force"}, {"dp", "force"}],
      #     level_gates: [
      #       {"jingluo-xue", "200"},
      #       {"xiantian-gong", "280"},
      #       {"yiyang-zhi", "280"}
      #     ],
      #     map_gates: [
      #       {"finger", "yiyang-zhi"},
      #       {"force", "xiantian-gong"},
      #       {"unarmed", "xiantian-gong"}
      #     ],
      #     prepared_gates: [{"finger", "yiyang-zhi"}, {"unarmed", "xiantian-gong"}],
      #     resource_gates: [{"max_neili", "5000"}, {"neili", "1000"}],
      #     var_gates: [{"i", "5"}]
      #   }
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{
      #     add_costs: [{"neili", "-600"}],
      #     affect_by: [],
      #     apply_adds: ["attack"],
      #     busy_lines: ["if (random(3) == 1 && ! target->is_busy())",
      #      "target->start_busy(1);", "me->start_busy(3 + random(3));"],
      #     remote_damage: true,
      #     set_flags: [],
      #     temp_set: []
      #   }
      #   - if (random(3) == 1 && ! target->is_busy())
      #   - target->start_busy(1);
      #   - me->start_busy(3 + random(3));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
