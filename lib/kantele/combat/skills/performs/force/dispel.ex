defmodule Kantele.Combat.Skills.Performs.Force.Dispel do
  @moduledoc """
  exert「dispel」（source force/dispel.c，由 translate_perform.py 骨架生成，inherit ?）

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
      #   %{"assign_refs": [], "level_gates": [], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "300"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"color_codes": ["HIG", "HIW", "MAG", "NOR", "WHT", "YEL"], "combat_messages": %{"fail": [], "other": [], "success": []}, "resource_adds": [{"neili", "-100"}, {"neili", "-250"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": false, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-250"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (target->is_busy())", "me->start_busy(1 + random(2));", "me->start_busy(2 + random(3));", "target->start_busy(1 + random(2));", "me->start_busy(3 + random(3));", "me->start_busy(6 + random(6));", "target->start_busy(4 + random(4));", "me->start_busy(1);", "me->start_busy(2);", "target->start_busy(1);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (target->is_busy())
      #   - me->start_busy(1 + random(2));
      #   - me->start_busy(2 + random(3));
      #   - target->start_busy(1 + random(2));
      #   - me->start_busy(3 + random(3));
      #   - me->start_busy(6 + random(6));
      #   - target->start_busy(4 + random(4));
      #   - me->start_busy(1);
      #   - me->start_busy(2);
      #   - target->start_busy(1);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
