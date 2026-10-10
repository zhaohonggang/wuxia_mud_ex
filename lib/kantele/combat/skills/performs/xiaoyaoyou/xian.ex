defmodule Kantele.Combat.Skills.Performs.Xiaoyaoyou.Xian do
  @moduledoc """
  perform「仙游诀」（source xiaoyaoyou/xian.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "dodge"}, {"dp", "parry"}, {"level", "xiaoyaoyou"}], "level_gates": [{"xiaoyaoyou", "100"}], "map_gates": [{"dodge", "xiaoyaoyou"}], "prepared_gates": [], "resource_gates": [{"neili", "100"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的逍遥游拳法不够熟练，难以施展", "你没有激发逍遥游为轻功，难以施展", "你现在的真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("dodge")", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["CYN", "HIG", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "$N" HIW "身子微晃，施出「" HIG "仙游诀"
      #                 HIW "」满场游走，步法洋洋洒洒，甚为飘逸。\n" NOR", "= CYN "可是$n" CYN "看破了$P" CYN "的身"
      #                          "法，并没有受到任何影响。\n" NOR"], "success": ["= HIR "$n" HIR "只见无数人影奔来，不由大"
      #                          "惊失色，攻势顿为缓滞。\n" NOR"]}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-50"}, {"neili", "-80"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-50"}, {"neili", "-80"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (target->is_busy())", "target->start_busy(level / 18 + 2);", "me->start_busy(1);", "me->start_busy(2);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (target->is_busy())
      #   - target->start_busy(level / 18 + 2);
      #   - me->start_busy(1);
      #   - me->start_busy(2);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
