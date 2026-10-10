defmodule Kantele.Combat.Skills.Performs.QingyunBian.Duan do
  @moduledoc """
  perform「duan」（source qingyun-bian/duan.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"power", "qingyun-bian"}], "level_gates": [{"force", "100"}, {"whip", "100"}], "map_gates": [], "prepared_gates": [], "resource_gates": [], "var_gates": [{"power", "150"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["[断云决]只能对战斗中的对手使用。\n", "你的基本内功火候未到，无法施展断云决！\n", "断云决需要精湛的青云鞭法方能有效施展！\n", "你的内力不够使用断云决！\n", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIM", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": [], "success": []}, "exp_compare": [{"10", "0"}, {"10", "2"}, {"10", "4"}, {"10", "6"}, {"10", "8"}], "resource_adds": [{"neili", "-power"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": [], "apply_adds": ["armor", "attack", "damage", "dodge"], "busy_lines": ["me->start_busy( 2 + random(2));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy( 2 + random(2));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
