defmodule Kantele.Combat.Skills.Performs.LingyuanXinfa.Break do
  @moduledoc """
  exert「break」（source lingyuan-xinfa/break.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [], "level_gates": [{"lingyuan-xinfa", "150"}], "map_gates": [], "prepared_gates": [], "resource_gates": [], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你只能对战斗中的对手使用「以柔破钢」。\n", "你的灵元心法火候不够，还不会使用「以柔破钢」。\n", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["CYN", "HIC", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIC "$N" HIC "沉肩滑步，自丹田中升起一股阴柔之气"
      #                 "顺着血脉经络传至双手劳宫穴，接着这股阴柔之气就"
      #                 "激射而出，喷向$n" HIC "手中的兵刃！\n" NOR", "= HIW "结果$p" HIW "手中的" +
      #                                  target_w->query("name") +
      #                                  "与这股阴柔之气一碰竟被震落在地上！\n" NOR", "= CYN "可是$p" CYN "急急拆招，躲了"
      #                                  "开去，使$P" CYN "的计谋没有得逞。\n" NOR"], "success": []}, "reset_action": true, "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}, "wield_actions": ["unequip"]}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": [], "apply_adds": [], "busy_lines": ["if (target->is_busy())", "me->start_busy(2);", "target->start_busy((int)me->query_skill("lingyuan-xinfa") / 20);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (target->is_busy())
      #   - me->start_busy(2);
      #   - target->start_busy((int)me->query_skill("lingyuan-xinfa") / 20);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
