defmodule Kantele.Combat.Skills.Performs.YiyangZhi.Heal do
  @moduledoc """
  perform「起死回生」（source yiyang-zhi/heal.c，由 translate_perform.py 骨架生成，inherit ?）

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
      #   %{"assign_refs": [], "level_gates": [{"jingluo-xue", "100"}, {"yiyang-zhi", "100"}], "map_gates": [{"finger", "yiyang-zhi"}], "prepared_gates": [{"finger", "yiyang-zhi"}], "resource_gates": [{"jing", "100"}, {"max_neili", "1500"}, {"neili", "1000"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所学的外功中没有这种功能。\n", "你要用真气为谁疗伤？\n", "战斗中无法运功疗伤。\n", "你无法给", "你的一阳指诀不够娴熟，难以施展", "你对经络学的了解不够，难以施展", "你没有激发一阳指，难以施展", "你没有准备一阳指，难以施展", "你必须激发一种内功才能施展", "你的内力修为太浅，难以施展", "你现在的真气不足，难以施展", "你现在的状态不佳，难以施展", "对方没有受伤，不需要接受治疗。\n"], "color_codes": ["HIC", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": [], "success": []}, "receive_damage_calls": [%{"formula": "100", "kind": "damage", "part": "qi", "source": None}, %{"formula": "50", "kind": "damage", "part": "jing", "source": None}], "resource_adds": [{"neili", "-800"}], "resource_queries": ["jing", "max_jing", "max_neili", "max_qi", "neili", "qi"], "resource_sets": [{"jing", "1"}, {"qi", "1"}], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-800"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (! target->is_busy())", "me->start_busy(10);"], "remote_damage": false, "set_flags": [{"jing", "1"}, {"qi", "1"}], "temp_set": []}
      #   - if (! target->is_busy())
      #   - me->start_busy(10);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
