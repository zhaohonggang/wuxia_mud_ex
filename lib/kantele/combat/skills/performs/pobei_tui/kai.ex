defmodule Kantele.Combat.Skills.Performs.PobeiTui.Kai do
  @moduledoc """
  perform「五岳为开」（source pobei-tui/kai.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"lvl", "pobei-tui"}], "level_gates": [{"force", "150"}, {"pobei-tui", "100"}], "map_gates": [{"unarmed", "pobei-tui"}], "prepared_gates": [{"unarmed", "pobei-tui"}], "resource_gates": [{"neili", "150"}], "var_gates": [{"i", "4"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你必须空手才能使用", "你的内功火候太浅，难以施展", "你的破碑腿不够娴熟，难以施展", "你现在没有激发破碑腿，难以施展", "你现在没有准备破碑腿，难以施展", "你现在真气太弱，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIC", "HIR", "NOR", "WHT"], "combat_messages": %{"fail": [], "other": ["WHT "只见$N" WHT "身形猛转，霎那间双腿流星般连环踢出，足带风尘，腿影将$n"
      #                 WHT "团团笼罩。\n" NOR", "= HIC "可是$n" HIC "凝神顿气，奋力抵挡，丝毫不"
      #                          "受腿影的干扰，。\n" NOR"], "success": ["= HIR "$n" HIR "见无数腿影向自己袭来，全然分辨"
      #                          "不清真伪，只得拼命运动抵挡。\n" NOR"]}, "resource_adds": [{"neili", "-100"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["me->start_busy(random(4));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(random(4));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
