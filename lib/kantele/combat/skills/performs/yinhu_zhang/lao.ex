defmodule Kantele.Combat.Skills.Performs.YinhuZhang.Lao do
  @moduledoc """
  perform「大海捞针」（source yinhu-zhang/lao.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "staff"}, {"dp", "parry"}], "level_gates": [{"force", "140"}, {"yinhu-zhang", "100"}], "map_gates": [{"staff", "yinhu-zhang"}], "prepared_gates": [], "resource_gates": [{"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你的内功火候不够，难以施展", "你现在的真气不够，难以施展", "你银瑚杖法火候不够，难以施展", "你没有激发银瑚杖法，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("staff")", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["CYN", "HIM", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIM "\n$N" HIM "一声暴喝，猛然间腾空而起，施出绝招「" HIW "大海捞"
      #                 "针" HIM "」，手中" + weapon->name() + HIM "从天而降，气势惊人地"
      #                 "袭向$n" HIM "。\n" NOR", "CYN "可是$n" CYN "奋力招架，左闪右避，好不容"
      #                          "易抵挡住了$N" CYN "的攻击。\n" NOR"], "success": ["COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 75,
      #                                              HIR "$n" HIR "完全无法看清招中虚实，只"
      #                                              "听「嘭」地一声，已被$N" HIR "击中肩膀。\n" NOR)"]}, "damage_formula": %{"formula": "ap + random(ap / 2)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}, {"neili", "-180"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}, "weapon_type": "staff"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-180"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(3);", "me->start_busy(4);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3);
      #   - me->start_busy(4);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
