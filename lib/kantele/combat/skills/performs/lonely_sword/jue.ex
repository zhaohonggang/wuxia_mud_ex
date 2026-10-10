defmodule Kantele.Combat.Skills.Performs.LonelySword.Jue do
  @moduledoc """
  perform「jue」（source lonely-sword/jue.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"skill", "lonely-sword"}], "level_gates": [], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "50"}], "var_gates": [{"jing_cost", "30"}, {"skill", "20"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["这里太嘈杂，你不能静下心来演练。\n", "「总诀式」不能在战斗中演练。\n", "你必须先去找一把剑。\n", "你的独孤九剑等级不够, 不能演练「总诀式」！\n", "你的内力不够，没有力气演练「总诀式」！\n", "你现在太累了，无法集中精神演练「总诀式」！\n", "你的实战经验不够，无法体会「总诀式」！\n"], "color_codes": ["HIG", "MAG", "NOR"], "combat_messages": %{"fail": [], "other": ["HIG "$N" HIG "使出独孤九剑之「总诀式」，将手中" +
      #                 weapon->name() + HIG "随意挥舞击刺。\n" NOR"], "success": []}, "improve_skill": ["improve_skill("], "receive_damage_calls": [%{"formula": "jing_cost", "kind": "damage", "part": "jing", "source": None}], "resource_adds": [{"neili", "-40 - random(10)"}], "resource_queries": ["jing", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": false, "uses_offensive_target": false}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(random(3));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(random(3));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
