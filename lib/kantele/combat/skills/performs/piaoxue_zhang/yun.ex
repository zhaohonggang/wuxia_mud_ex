defmodule Kantele.Combat.Skills.Performs.PiaoxueZhang.Yun do
  @moduledoc """
  perform「云海明灯」（source piaoxue-zhang/yun.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [], "level_gates": [{"force", "200"}, {"piaoxue-zhang", "150"}], "map_gates": [{"strike", "piaoxue-zhang"}], "prepared_gates": [{"strike", "piaoxue-zhang"}], "resource_gates": [{"max_neili", "2000"}, {"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你必须空手才能施展", "你的内功的修为不够，无法施展", "你的飘雪穿云掌修为不够，无法施展", "你的真气不够，无法施展", "你没有激发飘雪穿云掌，无法施展", "你没有准备使用飘雪穿云掌，无法施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "$N" HIW "一声暴喝，陡然施出飘雪穿云掌绝技「云海明灯」，瞬"
      #                 "间连续攻出数招。\n" NOR"], "success": []}, "resource_adds": [{"neili", "-100"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["me->start_busy(2 + random(3));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2 + random(3));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
