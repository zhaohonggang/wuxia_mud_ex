defmodule Kantele.Combat.Skills.Performs.ShenghuoLing.Xi do
  @moduledoc """
  perform「吸焰令」（source shenghuo-ling/xi.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "sword"}, {"dp", "parry"}, {"skill", "shenghuo-ling"}], "level_gates": [], "map_gates": [], "prepared_gates": [], "resource_gates": [{"max_neili", "1500"}, {"neili", "300"}], "var_gates": [{"skill", "140"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的兵器不对，不能使用圣火令法之", "对方没有使用武器，不能使用圣火令法之", "你的圣火令法等级不够, 不能使用圣火令法之", "你的内力修为不足，不能使用圣火令法之", "你的真气不够，不能使用圣火令法之", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("sword")", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["CYN", "HIM", "NOR"], "combat_messages": %{"fail": [], "other": ["HIM "突然$N" HIM "诡异的一笑，使出圣火令法之吸焰"
      #                 "令，手中" + weapon->name() + HIM "幻出数个小圈"
      #                 "，将$n" HIM "的" + weapon2->name() + HIM "紧紧"
      #                 "缠住。\n" NOR", "= HIM "$n" HIM "只见眼前无数寒光颤跃闪动，顿时只感"
      #                         "头晕目眩，手腕一麻，手中" + weapon2->name() + HIM
      #                         "已被$N" HIM "纳入怀中！\n" NOR", "= CYN "可是$n" CYN "看破$N" CYN "的企图，将手中兵"
      #                         "刃挥舞得密不透风，使得$N" CYN "无从下手。\n" NOR"], "success": []}, "hit_formula": %{"left_side": "ap + random(ap / 2)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}, {"neili", "-240"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-240"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(4);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(4);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
