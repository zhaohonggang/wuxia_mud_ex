defmodule Kantele.Combat.Skills.Performs.KuihuaMogong.Sheng do
  @moduledoc """
  perform「无声无息」（source kuihua-mogong/sheng.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "kuihua-mogong"}, {"dp", "dodge"}], "level_gates": [{"kuihua-mogong", "200"}], "map_gates": [{"dodge", "kuihua-mogong"}], "prepared_gates": [], "resource_gates": [{"max_neili", "3000"}, {"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的葵花魔功不够深厚，不会使用", "你的内力修为不足，难以施展", "你的真气不够，无法施展", "你还没有激发葵花魔功为轻功，无法施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("kuihua-mogong", 1) * 3 / 2 +
      #                me->query_skill("martial-cognize", 1)", "dp_formula": "target->query_skill("dodge") +
      #                target->query_skill("martial-cognize", 1)"}, "color_codes": ["CYN", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["= CYN "可是$p" CYN "看破了$P" CYN "的身法，并没"
      #                          "有受到任何影响。\n" NOR"], "success": ["HIR "$N" HIR "身子忽进忽退，身形诡秘异常，在$n"
      #                 HIR "身边飘忽不定。\n" NOR", "= HIR "结果$p" HIR "只能紧守门户，不敢妄自出击！\n" NOR"]}, "hit_formula": %{"left_side": "ap * 3 / 5 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-120"}, {"neili", "-80"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-120"}, {"neili", "-80"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (target->is_busy())", "target->start_busy(ap / 30 + 2);", "me->start_busy(1);", "me->start_busy(1 + random(2));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (target->is_busy())
      #   - target->start_busy(ap / 30 + 2);
      #   - me->start_busy(1);
      #   - me->start_busy(1 + random(2));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
