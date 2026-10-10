defmodule Kantele.Combat.Skills.Performs.LiumaiShenjian.Six do
  @moduledoc """
  perform「六脉剑气」（source liumai-shenjian/six.c，由 translate_perform.exs 骨架生成，inherit F_SSERVER）

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
      #     assign_refs: [{"ap", "finger"}, {"dp", "force"}, {"skill", "liumai-shenjian"}],
      #     level_gates: [{"force", "400"}],
      #     map_gates: [],
      #     prepared_gates: [{"finger", "liumai-shenjian"}],
      #     resource_gates: [{"max_neili", "7000"}, {"neili", "500"}],
      #     var_gates: [{"i", "6"}, {"skill", "220"}]
      #   }
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{
      #     add_costs: [{"neili", "-400"}],
      #     affect_by: [],
      #     apply_adds: ["dodge", "parry"],
      #     busy_lines: ["if (random(2) == 1 && ! target->is_busy())",
      #      "target->start_busy(1);", "me->start_busy(1 + random(5));"],
      #     remote_damage: false,
      #     set_flags: [],
      #     temp_set: []
      #   }
      #   - if (random(2) == 1 && ! target->is_busy())
      #   - target->start_busy(1);
      #   - me->start_busy(1 + random(5));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
