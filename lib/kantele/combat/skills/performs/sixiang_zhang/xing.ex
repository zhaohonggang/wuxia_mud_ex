defmodule Kantele.Combat.Skills.Performs.SixiangZhang.Xing do
  @moduledoc """
  perform「星罗棋布」（source sixiang-zhang/xing.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "strike"}, {"dp", "parry"}, {"skill", "sixiang-zhang"}], "level_gates": [], "map_gates": [{"strike", "sixiang-zhang"}], "prepared_gates": [{"strike", "sixiang-zhang"}], "resource_gates": [{"neili", "200"}], "var_gates": [{"skill", "60"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的四象掌法等级不够，难以施展", "你的真气不够，难以施展", "你没有激发四象掌法，难以施展", "你现在没有准备使用四象掌法，无法使用", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("strike")", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["CYN", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "$N" HIW "一声清啸，双掌纷飞贯出，掌影重重叠叠，虚实难"
      #                 "辨，全全笼罩$n" HIW "全身。\n" NOR", "= CYN "可是$p" CYN "的看破了$P" CYN
      #                          "的掌法，巧妙的拆招，没露半点破绽"
      #                          "。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 10,
      #                                              HIR "$n" HIR "一时无法勘破这玄奇的掌法"
      #                                              "，接连中了数招，身陷其中，无法自拔。\n"
      #                                              NOR)"]}, "damage_formula": %{"formula": "ap / 3 + random(ap / 3)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-50"}, {"neili", "-80"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-50"}, {"neili", "-80"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "if (ap / 2 + random(ap) > dp && ! target->is_busy())", "target->start_busy(ap / 60 + 1);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - if (ap / 2 + random(ap) > dp && ! target->is_busy())
      #   - target->start_busy(ap / 60 + 1);
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
