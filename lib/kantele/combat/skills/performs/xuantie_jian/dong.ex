defmodule Kantele.Combat.Skills.Performs.XuantieJian.Dong do
  @moduledoc """
  perform「大江东去」（source xuantie-jian/dong.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "sword"}, {"dp", "force"}], "level_gates": [{"force", "400"}, {"xuantie-jian", "200"}], "map_gates": [{"sword", "xuantie-jian"}], "prepared_gates": [], "resource_gates": [{"neili", "1000"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你的内功火候不够，难以施展", "你的玄铁剑法不够娴熟，难以施展", "你手中的", "你现在的内力不足，难以施展", "你没有激发玄铁剑法，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("sword") + me->query_str() * 5", "dp_formula": "target->query_skill("force") + target->query_str() * 5"}, "color_codes": ["CYN", "HIG", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "$N" HIW "暗自凝神，顿时一股气劲由身后澎湃迸发，接着单"
      #                 "手一振，手中" + wp + HIW "\n随即横空卷出，激得周围尘沙腾起"
      #                 "，所施正是玄铁剑法「" HIG "大江东去" HIW "」。\n"NOR", "= CYN "可是$n" CYN "看破了$N"
      #                          CYN "的企图，急忙斜跃避开。\n"NOR"], "success": ["= HIR "$n" HIR "只觉得一股大力传来，手中" + weapon_t->name() +
      #                          HIR "再也拿持不住，脱手而出！\n" NOR", "= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 120,
      #                                              HIR "结果$n" HIR "奋力招架，却被$N" HIR
      #                                              "这一剑震的飞起，口中鲜血狂吐不止！\n" NOR)"]}, "damage_formula": %{"formula": "ap + random(ap)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-120"}, {"neili", "-200"}, {"neili", "-400"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-120"}, {"neili", "-200"}, {"neili", "-400"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2 + random(2));", "target->start_busy(1);"], "remote_damage": true, "set_flags": [{"value", "0"}], "temp_set": []}
      #   - me->start_busy(2 + random(2));
      #   - target->start_busy(1);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
