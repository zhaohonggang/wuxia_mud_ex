defmodule Kantele.Combat.Skills.Performs.JiashaFumogong.Zhe do
  @moduledoc """
  perform「避云遮日」（source jiasha-fumogong/zhe.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "unarmed"}, {"dp", "parry"}], "level_gates": [{"jiasha-fumogong", "140"}], "map_gates": [{"unarmed", "jiasha-fumogong"}], "prepared_gates": [{"unarmed", "jiasha-fumogong"}], "resource_gates": [{"max_neili", "2000"}, {"neili", "400"}], "var_gates": [{"i", "9"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的内力的修为不够，现在无法使用", "你的袈裟伏魔功还不够娴熟，难以施展", "你现在没有激发袈裟伏魔功为拳脚，难以施展", "你现在没有准备使用袈裟伏魔功，难以施展", "你的真气不够，无法运用", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("unarmed") + me->query("con") * 20", "dp_formula": "target->query_skill("parry") + target->query("con") * 20"}, "color_codes": ["HIG", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": [], "success": ["HIG "$N" HIG "大喝一声，施出绝招「" HIR "避云遮日" HIG "」，顿时真气迸发，衣衫鼓动，双手"
      #                 "猛然如闪电般地拍向$n" HIG "。\n" NOR", "= HIR "$n" HIR "全身一颤，立足不稳，被$N"
      #                          HIR "这招击得飞起，重重的跌落在地上。\n" NOR"]}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-300"}, {"neili", "-500"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-300"}, {"neili", "-500"}], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["me->start_busy(3);", "//  if (random(5) < 2 && ! target->is_busy())", "//         target->start_busy(1);", "me->start_busy(1 + random(5));"], "remote_damage": false, "set_flags": [{"eff_jing", "0"}, {"eff_qi", "0"}], "temp_set": []}
      #   - me->start_busy(3);
      #   - //  if (random(5) < 2 && ! target->is_busy())
      #   - //         target->start_busy(1);
      #   - me->start_busy(1 + random(5));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
