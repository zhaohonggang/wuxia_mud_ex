defmodule Kantele.Combat.Skills.Performs.HanbingZhenqi.Freezing do
  @moduledoc """
  exert「寒冰真气」（source hanbing-zhenqi/freezing.c，由 translate_perform.py 骨架生成，inherit F_CLEAN_UP）

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
      #   %{"assign_refs": [{"skill", "hanbing-zhenqi"}], "level_gates": [], "map_gates": [], "prepared_gates": [], "resource_gates": [{"con", "34"}, {"max_neili", "2200"}, {"neili", "1000"}], "var_gates": [{"skill", "140"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所学的内功中没有这种功能。\n", "你现在正在施展", "你的先天根骨不足，无法施展", "你的寒冰真气不够，难以施展", "你的内力修为不足，难以施展", "你现在尚未曾运功，难以施展", "你目前的内力不够，难以施展"], "buff_delete": ["freezing"], "call_outs": [%{"args": "me, skill", "delay": "skill", "fn": "remove_effect"}], "callback_functions": [%{"body": "if (me->query_temp("freezing"))
      #           {
      #                   me->delete_temp("freezing");
      #                   tell_object(me, "你的" FRE "运行完毕，将内力收回丹田。\n");", "name": "remove_effect", "params": "object me", "return_type": "void"}], "color_codes": ["HIW", "NOR"], "combat_messages": %{"fail": [], "other": [], "success": []}, "resource_adds": [{"neili", "-300"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": false, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-300"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(3);"], "remote_damage": false, "set_flags": [], "temp_set": ["freezing"]}
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
