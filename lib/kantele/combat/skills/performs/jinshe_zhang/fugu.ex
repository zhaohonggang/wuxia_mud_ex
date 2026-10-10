defmodule Kantele.Combat.Skills.Performs.JinsheZhang.Fugu do
  @moduledoc """
  perform「fugu」（source jinshe-zhang/fugu.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [], "level_gates": [{"jinshe-zhang", "100"}], "map_gates": [], "prepared_gates": [{"strike", "jinshe-zhang"}], "resource_gates": [{"neili", "300"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["附骨缠身只能对战斗中的对手使用。\n", "你不是空手，不能使用附骨缠身。\n", "你的金蛇掌不够娴熟，不会使用附骨缠身。\n", "你现在内力太弱，不能使用附骨缠身。\n", "你现在没有激发金蛇掌法，无法使用附骨缠身。\n", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["CYN", "HIC", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["HIC "$N" HIC "大喝一声，缠身而上左手一探刁住$n"
      #                 HIC "手腕，右掌猛下杀手！\n"NOR", "CYN "可是$p" CYN "识破了$P"
      #                         CYN "这一招，手肘一送，摆脱了对方控制。\n"NOR"], "success": ["HIR "结果$n" HIR "被$N" HIR "的左手所制，"
      #                         "在「附骨缠身」下，一时竟然无法还手！\n" NOR"]}, "resource_adds": [{"neili", "-150"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-150"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (target->is_busy() ||", "if (! target->is_busy())", "target->start_busy(1);", "me->start_busy(2);", "me->start_busy(2);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (target->is_busy() ||
      #   - if (! target->is_busy())
      #   - target->start_busy(1);
      #   - me->start_busy(2);
      #   - me->start_busy(2);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
