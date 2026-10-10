defmodule Kantele.Combat.Skills.Performs.ShangqingJian.Zhuo do
  @moduledoc """
  perform「浊流剑」（source shangqing-jian/zhuo.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "sword"}, {"dp", "parry"}], "level_gates": [{"force", "200"}, {"shangqing-jian", "140"}], "map_gates": [{"sword", "shangqing-jian"}], "prepared_gates": [], "resource_gates": [{"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你的内功的修为不够，难以施展", "你的上清剑法修为不够，难以施展", "你的真气不够，难以施展", "你没有激发上清剑法，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("sword")", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["CYN", "HIR", "NOR", "WHT"], "combat_messages": %{"fail": [], "other": ["WHT "只见$N" WHT "手中" + weapon->name() + WHT "一抖，施出上清剑法"
      #                 "「浊流剑」，霎时无数剑光罩向$n" WHT "！\n" NOR", "= CYN "可是$n" CYN "看破" CYN "$N"
      #                          CYN "的招数，飞身一纵，避开了这"
      #                          "一剑。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 60,
      #                                              HIR "$n" HIR "只感剑光夺目，顿时眼花缭"
      #                                              "乱，被$N" HIR "一剑刺中，鲜血飞溅。\n"
      #                                              NOR)"]}, "damage_formula": %{"formula": "ap / 2 + random(ap / 2)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}, {"neili", "-50"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-50"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
