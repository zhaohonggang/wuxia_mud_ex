defmodule Kantele.Combat.Skills.Performs.JieshouJiushi.Jie do
  @moduledoc """
  perform「截筋断脉」（source jieshou-jiushi/jie.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "hand"}, {"dp", "parry"}, {"skill", "jieshou-jiushi"}], "level_gates": [], "map_gates": [{"hand", "jieshou-jiushi"}], "prepared_gates": [{"hand", "jieshou-jiushi"}], "resource_gates": [{"max_neili", "800"}, {"neili", "200"}], "var_gates": [{"skill", "100"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的截手九式等级不够，难以施展", "你的内力修为不足，难以施展", "你的内力不够，难以施展", "你没有激发截手九式，难以施展", "你现在没有准备使用截手九式，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("hand")", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["CYN", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["= CYN "$n" CYN "见状大吃一惊，急忙向后猛退数步，"
      #                          "终于避开了$N" CYN "这一击。\n" NOR"], "success": ["HIR "$N" HIR "身形一展，陡然跃至$n" HIR "跟前，十指箕张，直锁$n"
      #                 HIR "要穴，正是截手九式绝技「截筋断脉」。\n" NOR", "= COMBAT_D->do_damage(me, target, REMOTE_ATTACK,
      #                          damage, 10, HIR "$n" HIR "奋力格挡，可还是被$N"
      #                                      HIR "截住腕部要穴，只觉眼前一黑，"
      #                                      "几欲晕倒。\n" NOR)"]}, "damage_formula": %{"formula": "skill / 2 + random(skill / 3)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "receive_damage_calls": [%{"formula": "damage", "kind": "damage", "part": "jing", "source": None}, %{"formula": "damage", "kind": "wound", "part": "jing", "source": None}, %{"formula": "damage * 3 / 2", "kind": "damage", "part": "qi", "source": None}, %{"formula": "damage * 3 / 2", "kind": "wound", "part": "qi", "source": None}], "resource_adds": [{"neili", "-100"}, {"neili", "-200"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-200"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(3);", "target->start_busy(1);", "me->start_busy(4);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3);
      #   - target->start_busy(1);
      #   - me->start_busy(4);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
