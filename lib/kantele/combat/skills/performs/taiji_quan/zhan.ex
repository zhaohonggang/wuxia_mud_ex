defmodule Kantele.Combat.Skills.Performs.TaijiQuan.Zhan do
  @moduledoc """
  perform「粘字诀」（source taiji-quan/zhan.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "unarmed"}, {"dp", "parry"}, {"skill", "taiji-quan"}], "level_gates": [], "map_gates": [{"unarmed", "taiji-quan"}], "prepared_gates": [{"unarmed", "taiji-quan"}], "resource_gates": [{"neili", "200"}], "var_gates": [{"skill", "150"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的太极拳等级不够，难以施展", "你的真气不够，难以施展", "你没有激发太极拳，难以施展", "你现在没有准备使用太极拳，无法使用", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("unarmed")", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["CYN", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "$N" HIW "连消带打，双手成圆形击出，这"
      #                 "正是太极拳「圆转不断」四字的精意。只\n见$N"
      #                 HIW "随即平圈、立圈、正圈、斜圈，一个跟着一"
      #                 "个，一个个太极圆圈顿时笼\n罩$n" HIW "四面"
      #                 "八方。\n" NOR", "= CYN "可是$p" CYN "的看破了$P" CYN
      #                          "的企图，巧妙的拆招，没露半点破绽"
      #                          "。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 20,
      #                                              HIR "$n" HIR "登时便被套得跌跌撞撞，身"
      #                                              "不由主的立足不稳，犹如中酒昏迷。\n"
      #                                              NOR)"]}, "damage_formula": %{"formula": "ap / 4 + random(ap / 4)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap * 4 / 3)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-10"}, {"neili", "-30"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-10"}, {"neili", "-30"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "if (ap / 2 + random(ap) > dp && ! target->is_busy())", "target->start_busy(ap / 50 + 1);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - if (ap / 2 + random(ap) > dp && ! target->is_busy())
      #   - target->start_busy(ap / 50 + 1);
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
