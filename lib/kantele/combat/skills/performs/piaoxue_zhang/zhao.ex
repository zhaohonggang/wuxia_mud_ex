defmodule Kantele.Combat.Skills.Performs.PiaoxueZhang.Zhao do
  @moduledoc """
  perform「佛光普照」（source piaoxue-zhang/zhao.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "strike"}, {"dp", "dodge"}], "level_gates": [{"force", "300"}, {"piaoxue-zhang", "180"}], "map_gates": [{"force", "emei-jiuyang"}, {"force", "jiuyang-shengong"}, {"force", "shaolin-jiuyang"}, {"force", "wudang-jiuyang"}, {"strike", "piaoxue-zhang"}], "prepared_gates": [{"strike", "piaoxue-zhang"}], "resource_gates": [{"max_neili", "3500"}, {"neili", "1000"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你必须空手才能施展", "你的内功的修为不够，无法施展", "你的飘雪穿云掌修为不够，无法施展", "你的真气不够，无法施展", "你没有激发内功为九阳神功，无法施展", "你没有激发飘雪穿云掌，无法施展", "你没有准备飘雪穿云掌，无法施展", "你必须将全身功力尽数提起才能施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("strike") +
      #                me->query_skill("force") +
      #                me->query("str") * 5", "dp_formula": "target->query_skill("dodge") +
      #                target->query_skill("force") +
      #                target->query("con") * 5"}, "color_codes": ["CYN", "HIR", "HIW", "HIY", "NOR"], "combat_messages": %{"fail": ["= CYN "可是$p" CYN "内力深厚，及时摆脱了" 
      #                          CYN "$P" CYN "内力的牵扯，躲开了这一击！\n" NOR"], "other": ["HIY "$N" HIY "运起全身功力，顿时真气迸发，全身骨骼噼啪作"
      #                 "响，猛然一掌向$n" HIY "\n全力拍出，力求一击毙敌，正是一"
      #                 "招「佛光普照」。\n" NOR", "= HIW "只听轰然一声巨响，$n" HIW "已被一招正中，可$N"
      #                          HIW "只觉全身内力犹如江河入\n海，又如水乳交融，登"
      #                          "时消失得无影无踪。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 100,
      #                                              HIR "只听轰然一声巨响，$n" HIR "被$N"
      #                                              HIR "一招正中，身子便如稻草般平平飞出"
      #                                              "，重\n重摔在地下，呕出一大口鲜血，动"
      #                                              "也不动。\n" NOR)"]}, "damage_formula": %{"formula": "random(ap / 3) + ap / 3"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-400"}, {"neili", "-600"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-400"}, {"neili", "-600"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(3);", "me->start_busy(3);", "me->start_busy(4);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3);
      #   - me->start_busy(3);
      #   - me->start_busy(4);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
