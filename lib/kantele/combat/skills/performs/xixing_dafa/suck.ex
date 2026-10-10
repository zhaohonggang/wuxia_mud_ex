defmodule Kantele.Combat.Skills.Performs.XixingDafa.Suck do
  @moduledoc """
  exert「suck」（source xixing-dafa/suck.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"amount", "xixing-dafa"}, {"dp", "force"}, {"sp", "force"}], "level_gates": [{"xixing-dafa", "200"}], "map_gates": [], "prepared_gates": [], "resource_gates": [{"max_neili", "1"}, {"max_neili", "100"}, {"neili", "100"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["在这里不能攻击他人。\n", "你只能吸取战斗中的对手的丹元！\n", "搞错了！只有活着的生物才能有丹元！\n", "你刚刚吸取过丹元！\n", "你的吸星大法尚未大成，还", "你的内力不够，不能使用吸星大法。\n", "你的内功水平有限，再吸取也是徒劳。\n"], "ap_dp_formulas": %{"dp_formula": "target->query_skill("force")"}, "buff_delete": ["sucked"], "callback_functions": [%{"body": "me->delete_temp("sucked");", "name": "del_sucked", "params": "object me", "return_type": "void"}], "color_codes": ["HIG", "HIR", "HIW", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": [], "success": []}, "resource_adds": [{"max_neili", "-amount"}, {"max_neili", "amount"}, {"neili", "-10"}], "resource_queries": ["max_neili", "neili"], "resource_sets": [{"max_neili", "0"}], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-10"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(4 + random(4));", "if (! target->is_busy()) target->start_busy(2);", "me->start_busy(7);"], "remote_damage": false, "set_flags": [{"max_neili", "0"}], "temp_set": ["sucked"]}
      #   - me->start_busy(4 + random(4));
      #   - if (! target->is_busy()) target->start_busy(2);
      #   - me->start_busy(7);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
