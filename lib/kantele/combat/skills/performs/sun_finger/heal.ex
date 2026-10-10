defmodule Kantele.Combat.Skills.Performs.SunFinger.Heal do
  @moduledoc """
  perform「heal」（source sun-finger/heal.c，由 translate_perform.py 骨架生成，inherit ?）

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
      #   %{"assign_refs": [], "level_gates": [], "map_gates": [], "prepared_gates": [], "resource_gates": [{"jing", "100"}, {"max_neili", "1500"}, {"neili", "1000"}, {"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你要用真气为谁疗伤？\n", "你只能替别人疗伤。\n", "战斗中无法运功疗伤！\n", "你不能给", "你必须激发一种内功才能运功疗伤。\n", "你的内力还浅，不是运功疗伤。\n", "你的真气现在不够，不能贸然行功。\n", "你的气现在不够，不要贸然行功。\n", "你的精现在不够，不要贸然行功。\n", "对方没有受伤，不需要接受治疗。\n"], "color_codes": ["HIC", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": [], "success": []}, "receive_damage_calls": [%{"formula": "150", "kind": "damage", "part": "qi", "source": None}, %{"formula": "80", "kind": "damage", "part": "jing", "source": None}], "resource_adds": [{"neili", "-1000"}], "resource_queries": ["jing", "max_jing", "max_neili", "max_qi", "neili", "qi"], "resource_sets": [{"jing", "1"}, {"qi", "1"}], "target_logic": %{"requires_fighting": true, "requires_living": false, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-1000"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(10);"], "remote_damage": false, "set_flags": [{"jing", "1"}, {"qi", "1"}], "temp_set": []}
      #   - me->start_busy(10);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
