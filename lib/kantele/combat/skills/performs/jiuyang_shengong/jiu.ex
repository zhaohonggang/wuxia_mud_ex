defmodule Kantele.Combat.Skills.Performs.JiuyangShengong.Jiu do
  @moduledoc """
  perform「九曦混阳」（source jiuyang-shengong/jiu.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "unarmed"}, {"dp", "parry"}], "level_gates": [{"jiuyang-shengong", "200"}], "map_gates": [{"force", "jiuyang-shengong"}, {"unarmed", "jiuyang-shengong"}], "prepared_gates": [{"unarmed", "jiuyang-shengong"}], "resource_gates": [{"max_neili", "4000"}, {"neili", "500"}], "var_gates": [{"i", "9"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的内力的修为不够，现在无法使用", "你的九阳神功还不够娴熟，难以施展", "你现在没有激发九阳神功为拳脚，难以施展", "你现在没有激发九阳神功为内功，难以施展", "你现在没有准备使用九阳神功，难以施展", "你的真气不够，无法运用", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("unarmed") + me->query("con") * 20", "dp_formula": "target->query_skill("parry") + target->query("con") * 20"}, "color_codes": ["HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["= HIY "$n" HIY "只见$N" HIY "无数气团向自己袭来，连"
      #                          "忙强振精神，勉强抵挡。\n" NOR"], "success": ["HIR "$N" HIR "大喝一声，顿时一股浩荡无比的真气至体内迸发，双掌"
      #                 "猛然翻滚，朝$n" HIR "闪电般拍去。\n" NOR", "= HIR "$n" HIR "只觉周围空气炽热无比，又见无数气团向"
      #                          "自己袭来，顿感头晕目眩，不知该如何抵挡。\n" NOR"]}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-300"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-300"}], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["if (random(5) < 2 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(8));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (random(5) < 2 && ! target->is_busy())
      #   - target->start_busy(1);
      #   - me->start_busy(1 + random(8));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
