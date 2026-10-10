defmodule Kantele.Combat.Skills.Performs.KuihuaMogong.Roar do
  @moduledoc """
  exert「roar」（source kuihua-mogong/roar.c，由 translate_perform.py 骨架生成，inherit F_CLEAN_UP）

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
      #   %{"assign_refs": [{"skill", "force"}], "level_gates": [], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "100"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你的内力不够。\n", "这里不能攻击别人! \n"], "color_codes": ["HIY", "NOR"], "combat_messages": %{"fail": [], "other": [], "success": []}, "damage_formula": %{"formula": "skill - ((int)ob[i]->query("max_neili") / 10)"}, "receive_damage_calls": [%{"formula": "damage * 3", "kind": "damage", "part": "qi", "source": "me"}, %{"formula": "damage * 2", "kind": "wound", "part": "qi", "source": "me"}, %{"formula": "10", "kind": "damage", "part": "qi", "source": None}], "resource_adds": [{"neili", "-100"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": false, "requires_living": false, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(5);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(5);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
