defmodule Kantele.Combat.Skills.Performs.HuntianBaojian.Sword do
  @moduledoc """
  exert「sword」（source huntian-baojian/sword.c，由 translate_perform.py 骨架生成，inherit F_CLEAN_UP）

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
      #   %{"assign_refs": [], "level_gates": [], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "50"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["呵气成剑只能对自己使用。\n", "你的内力不够。\n", "你手中已经有武器了。\n", "你身上已经有一束剑气了。\n"], "call_outs": [%{"args": "me", "delay": "50", "fn": "dest_sword"}, %{"args": "me", "delay": "2", "fn": "dest_sword"}], "callback_functions": [%{"body": "object weapon;
      #   
      #           if (objectp(weapon = me->query_temp("weapon"))
      #              && (string)weapon->query("skill_type") == "sword"
      #              && (string)weapon->query("id") == "jian qi")
      #           {
      #     ", "name": "dest_sword", "params": "object me", "return_type": "void"}], "color_codes": ["HIW", "NOR"], "combat_messages": %{"fail": [], "other": [], "success": []}, "resource_adds": [{"neili", "-30"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": false, "uses_offensive_target": false}, "weapon_forbidden": ["sword"], "wield_actions": ["wield"]}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-30"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(1);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
