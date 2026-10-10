defmodule Kantele.Combat.Skills.Performs.LingsheQuan.Rou do
  @moduledoc """
  perform「rou」（source lingshe-quan/rou.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "cuff"}, {"damage", "force"}, {"dp", "dodge"}], "level_gates": [{"lingshe-quan", "100"}], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["「柔字诀」只能对战斗中的对手使用。\n", "你要施展拳法不能使用武器。\n", "你的灵蛇拳法不够娴熟，现在还无法使用「柔字诀」。\n", "你现在真气不够，无法运用「柔字诀」。\n", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("cuff") + me->query_skill("training", 1)", "dp_formula": "target->query_skill("dodge")"}, "color_codes": ["HIC", "HIG", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["HIG "$N" HIG "一拳打出，半途中手臂忽然不可思议的转了个圈子，打向$n"
      #                 HIG "，令$p" HIG "防不胜防。\n"NOR", "= HIC "可是$p" HIC "见机的快，连忙施展身法，避开了拳。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 50,
      #                                              HIR "只见$n" HIR "大吃一惊，仓皇之下不及闪躲，被$N"
      #                                              HIR "一拳打了个正中，闷哼一声，连退数步！\n" NOR)"]}, "damage_formula": %{"formula": "(int)me->query_skill("force") + (int)me->query_skill("cuff")"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}, {"neili", "-50"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-50"}], "affect_by": [], "apply_adds": [], "busy_lines": ["target->start_busy(1);", "me->start_busy(2);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - target->start_busy(1);
      #   - me->start_busy(2);
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
