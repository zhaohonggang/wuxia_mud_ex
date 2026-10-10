defmodule Kantele.Combat.Skills.Performs.LianhuanMizongtui.Lian do
  @moduledoc """
  perform「夺命连环」（source lianhuan-mizongtui/lian.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"lvl", "lianhuan-mizongtui"}], "level_gates": [{"dodge", "150"}, {"force", "150"}, {"lianhuan-mizongtui", "120"}], "map_gates": [], "prepared_gates": [{"unarmed", "lianhuan-mizongtui"}], "resource_gates": [{"max_neili", "1800"}, {"neili", "200"}], "var_gates": [{"i", "5"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的连环迷踪腿不够娴熟，难以施展", "你的内力的修为不够，现在无法使用", "你的内功火候不够，难以施展", "你的轻功火候不够，难以施展", "你现在没有准备使用连环迷踪腿，难以施展", "你现在真气太弱，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIC", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "陡见$N" HIW "全身飞速旋转，双腿忽前忽后，接连贯出数腿，流星般疾射$n"
      #                 HIW "胸口。\n" NOR", "= HIC "可是$n" HIC "凝神顿气，奋力抵挡，丝"
      #                          "毫不受腿影的干扰，。\n" NOR"], "success": ["= HIR "$n" HIR "顿时觉得眼花缭乱，无数条腿"
      #                          "向自己奔来，只得拼命运动抵挡。\n" NOR"]}, "resource_adds": [{"neili", "-150"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-150"}], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["me->start_busy(random(5));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(random(5));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
