defmodule Kantele.Combat.Skills.Performs.YuezhaoGong.Shi do
  @moduledoc """
  perform「弑元诀」（source yuezhao-gong/shi.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "claw"}, {"damage", "yuezhao-gong"}, {"dp", "dodge"}], "level_gates": [{"force", "200"}, {"yuezhao-gong", "130"}], "map_gates": [{"claw", "yuezhao-gong"}], "prepared_gates": [{"claw", "yuezhao-gong"}], "resource_gates": [{"neili", "300"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的内功火候不够，难以施展", "你越爪功等级不够，难以施展", "你没有激发越爪功，难以施展", "你没有准备越爪功，难以施展", "你现在的真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("claw")", "dp_formula": "target->query_skill("dodge")"}, "color_codes": ["HIC", "HIR", "NOR", "WHT"], "combat_messages": %{"fail": [], "other": ["= HIC "可是$p" HIC "身手敏捷，身形急转，巧妙的躲过了$P"
      #                          HIC "的攻击。\n"NOR"], "success": ["WHT "$N" WHT "施出越爪功「" HIR "弑元诀" NOR + WHT "」绝技，右"
      #                 "手一横，直直抓向$n" WHT "破绽所在。\n" NOR", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 55,
      #                                      HIR "只听$n" HIR "一声惨嚎，竟被$N" HIR
      #                                              "的五指抓破气门，鲜血登时四处飞溅！\n" NOR)"]}, "damage_formula": %{"formula": "me->query_skill("yuezhao-gong", 1)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}, {"neili", "-50"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-50"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
