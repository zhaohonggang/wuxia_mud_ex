defmodule Kantele.Combat.Skills.Performs.RiyueLun.Po do
  @moduledoc """
  perform「破立势」（source riyue-lun/po.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "force"}, {"dp", "force"}], "level_gates": [{"force", "180"}, {"riyue-lun", "120"}], "map_gates": [{"force", "longxiang-gong"}, {"hammer", "riyue-lun"}], "prepared_gates": [], "resource_gates": [{"max_neili", "1500"}, {"neili", "500"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你现在无暇施展", "你所使用的武器不对，难以施展", "你没有激发日月轮法，难以施展", "你没有激发龙象般若功，难以施展", "你的日月轮法火候不足，难以施展", "你的内功火候不足，难以施展", "你的内力修为不足，难以施展", "你现在的真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("force") + me->query("str") * 10", "dp_formula": "target->query_skill("force") + target->query("con") * 10"}, "color_codes": ["CYN", "HIR", "HIY", "NOR"], "combat_exp_formulas": [{"lvl", "to_int(pow(to_float(me->query("combat_exp") * 10), 1.0 / 3))"}], "combat_messages": %{"fail": [], "other": ["HIY "$N" HIY "单手高举" + wp + HIY "奋力朝$n" HIY "砸下，气"
      #                 "浪迭起，全然把$n" HIY "卷在其中！\n" NOR", "= CYN "却见$p" CYN "浑不在意，轻轻一闪就躲过了$P"
      #                  CYN "的凶悍招数。\n"NOR"], "success": ["= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,
      #                                              HIR "$n" HIR "被$N" HIR "这强悍无比的"
      #                                              "内劲冲击得左摇右晃，接连中招，狂喷鲜"
      #                                              "血。\n" NOR)"]}, "damage_formula": %{"formula": "ap / 2 + random(ap / 2)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-150"}, {"neili", "-300"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "hammer"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-150"}, {"neili", "-300"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(3);", "me->start_busy(2);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3);
      #   - me->start_busy(2);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
