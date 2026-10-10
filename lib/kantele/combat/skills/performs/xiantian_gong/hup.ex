defmodule Kantele.Combat.Skills.Performs.XiantianGong.Hup do
  @moduledoc """
  exert「五气朝元」（source xiantian-gong/hup.c，由 translate_perform.py 骨架生成，inherit F_CLEAN_UP）

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
      #   %{"assign_refs": [{"skill", "force"}], "level_gates": [{"xiantian-gong", "200"}], "map_gates": [], "prepared_gates": [], "resource_gates": [{"max_neili", "1000"}, {"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所学的内功中没有这种功能。\n", "你先天功不够深厚，难以施展", "你的内力修为不足，难以施展", "你现在的真气不够，难以施展"], "color_codes": ["HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "$N" HIW "缓缓吐出一口气，顿时气脉通畅，脸色渐渐的变"
      #                 "得平和。\n" NOR"], "success": []}, "resource_adds": [{"neili", "-neili_cost"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": false, "requires_living": false, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(3);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
