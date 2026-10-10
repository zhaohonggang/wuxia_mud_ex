defmodule Kantele.Combat.Skills.Performs.LongxiangGong.Tun do
  @moduledoc """
  perform「龙吞势」（source longxiang-gong/tun.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "unarmed"}, {"dp", "parry"}, {"foc", "force"}], "level_gates": [{"longxiang-gong", "180"}], "map_gates": [{"force", "longxiang-gong"}, {"unarmed", "longxiang-gong"}], "prepared_gates": [{"unarmed", "longxiang-gong"}], "resource_gates": [{"max_neili", "3000"}, {"neili", "500"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的龙象般若功修为不够，难以施展", "你的内力修为不足，难以施展", "你没有激发龙象般若功为拳脚，难以施展", "你没有激发龙象般若功为内功，难以施展", "你没有准备使用龙象般若功，难以施展", "你现在的真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("unarmed") +
      #                me->query_skill("force")", "dp_formula": "target->query_skill("parry") +
      #                target->query_skill("force")"}, "buff_delete": ["long_tun"], "call_outs": [%{"args": "me", "delay": "50", "fn": "remove_effect"}], "callback_functions": [%{"body": "if (me->query_temp("long_tun"))
      #           {
      #                   me->delete_temp("long_tun");
      #                   tell_object(me, "你经过调气养息，又可以继续施展" TUN "了。\n");", "name": "remove_effect", "params": "object me", "return_type": "void"}], "color_codes": ["CYN", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["= CYN "可是$n" CYN "见$N" CYN "此招来势非凡，急"
      #                          "忙向后横移数尺，终于躲避开来。\n" NOR"], "success": ["HIY "$N" HIY "双臂左右分张，形若龙嘴，所施正是龙象般若功绝学「"
      #                 HIR "龙吞势" HIY "」。霎时呼\n啸声大作，但见一股澎湃无比的罡劲"
      #                 "至$N" HIY "双掌间涌出，云贯向$n" HIY "而去。\n" NOR", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 80,
      #                                                  HIR "$n" HIR "一声哀嚎，被$N" HIR "的罡"
      #                                                  "气划中气门，真气在体内四处乱窜，惨不堪"
      #                                                  "言。\n" NOR)"]}, "damage_formula": %{"formula": "ap / 2 + random(ap) + random(foc)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-200"}, {"neili", "-300"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-200"}, {"neili", "-300"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(3);", "me->start_busy(4);"], "remote_damage": true, "set_flags": [], "temp_set": ["long_tun"]}
      #   - me->start_busy(3);
      #   - me->start_busy(4);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
