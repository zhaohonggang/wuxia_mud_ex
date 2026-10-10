defmodule Kantele.Combat.Skills.Performs.JiuyinShengong.Zhen do
  @moduledoc """
  perform「真·天诛龙蛟诀」（source jiuyin-shengong/zhen.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "whip"}, {"dp", "force"}], "level_gates": [{"force", "300"}, {"jiuyin-shengong", "220"}], "map_gates": [{"whip", "jiuyin-shengong"}], "prepared_gates": [], "resource_gates": [{"neili", "400"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你使用的外功中没有这种功能。\n", "你使用的武器不对。\n", "你的内功火候不够，使不了", "你的九阴神功功力太浅，使不了", "你的真气不够，无法使用", "你没有激发九阴神功为鞭法，使不了", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("whip") + me->query_skill("force") + me->query_skill("martial-cognize", 1)", "dp_formula": "target->query_skill("force") + target->query_skill("parry") + target->query_skill("martial-cognize", 1)"}, "color_codes": ["CYN", "HIC", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "$N" HIW "诡异的一笑，手中" + weapon->name() +
      #             HIW "犹如一条银龙猛然飞向$n" HIW "，正是九阴真经中的"
      #                 "绝招「" HIC "真·天诛龙蛟诀" HIW "」！\n" NOR", "= CYN "可是$p" CYN "飞身一跃而起，躲避开了" CYN "$P" CYN "的攻击！\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 100,
      #                                      HIR "结果$n" HIR "一声惨叫，未能看破$N" HIR "的企图，被这一鞭硬击在胸口，鲜血飞"
      #                                          "溅，皮肉绽开！\n" NOR)"]}, "damage_formula": %{"formula": "ap + random(ap / 2)"}, "hit_formula": %{"left_side": "ap * 11 / 20 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}, {"neili", "-300"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "whip"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-300"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
