defmodule Kantele.Combat.Skills.Performs.DuguJiujian.Jue do
  @moduledoc """
  perform「总诀式」（source dugu-jiujian/jue.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"skill", "dugu-jiujian"}], "level_gates": [], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "85"}], "var_gates": [{"jing_cost", "30"}, {"skill", "60"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你周围过于嘈杂，难以演练", "你使用的武器不对，难以演练", "你的独孤九剑等级不够，难以演练", "你的基本剑法等级有限，难以演练", "你现在真气不足，难以演练", "你现在精神不佳，难以演练", "你实战经验不足，难以演练"], "color_codes": ["HIC", "HIW", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIC "$N" HIC "使出独孤九剑之「" HIW "总诀式"
      #                 HIC "」，将手中" + weapon->name() + HIC "随"
      #                 "意挥舞击刺。\n" NOR"], "success": []}, "improve_skill": ["improve_skill("], "receive_damage_calls": [%{"formula": "jing_cost", "kind": "damage", "part": "jing", "source": None}], "resource_adds": [{"neili", "-50 - random(30)"}], "resource_queries": ["jing", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": false, "uses_offensive_target": false}, "weapon_type": "sword"}
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
