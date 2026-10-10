defmodule Kantele.Combat.Skills.Performs.LongxiangGong.Zhen do
  @moduledoc """
  perform「真·般若极」（source longxiang-gong/zhen.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "unarmed"}, {"dp", "parry"}], "level_gates": [{"longxiang-gong", "390"}], "map_gates": [{"force", "longxiang-gong"}, {"unarmed", "longxiang-gong"}], "prepared_gates": [{"unarmed", "longxiang-gong"}], "resource_gates": [{"max_neili", "7000"}, {"neili", "1000"}], "var_gates": [{"i", "8"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的龙象般若功修为不够，难以施展", "你的内力修为不足，难以施展", "你没有激发龙象般若功为拳脚，难以施展", "你没有激发龙象般若功为内功，难以施展", "你没有准备使用龙象般若功，难以施展", "你现在的真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("unarmed") + me->query("con") * 10", "dp_formula": "target->query_skill("parry") + target->query("dex") * 10"}, "color_codes": ["HIR", "HIW", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "$N" HIY "仰天一声怒嚎，将龙象般若功提运至极限，全身顿时罡劲"
      #                 "迸发，真气蒸腾而出，笼罩$N" HIY "\n四方！电光火石间，$N" HIY "双"
      #                 "拳已携着雷霆万钧之势崩击而出，卷起万里尘埃，正是密宗绝学：\n\n" NOR", "= HIW
      #           "        般      般般般           若        若           极    极极极极极极\n"
      #           "    般般般般    般  般       若若若若若若若若若若       极       极    极\n"
      #           "    般    般    般  般           若        若       极极极极极  极    极\n"
      #           "    般 般 般 般般    般般          若                 极极极  极极极 极极极\n"
      #           "  般般般般般般             若若若若若若若若若若若若  极 极 极  极极     极\n"
      #           "    般    般   般般般般         若                   极 极 极  极 极   极\n"
      #           "    般 般 般    般  般        若 若若若若若若若      极 极 极 极   极极\n"
      #           "    般    般     般般       若   若          若         极   极     极\n"
      #           "   般    般   般般  般般         若若若若若若若         极  极  极极极极极\n\n" NOR", "= HIY "$N" HIY "一道掌力打出，接着便涌出了第二道、第三道掌力，掌势"
      #                  "连绵不绝，气势如虹！直到$N" HIY "\n第十三道掌力打完，四周所笼罩"
      #                  "着的罡劲方才慢慢消退！而$n" HIY "此时却已是避无可避！\n\n" NOR", "= HIY "$n" HIY "见$N" HIY "来势迅猛之极，甚难防备，连"
      #                          "忙振作精神，小心抵挡。\n" NOR"], "success": ["= HIR "$n" HIR "全然无力阻挡，竟被$N"
      #                          HIR "一下击得飞起，重重的跌落在地上。\n" NOR", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 90,
      #                                                      HIR "$n" HIR "不及闪避，顿被$N" HIR
      #                                   HIR "一下击中，尽伤三焦六脉。\n" NOR)", "= HIR "$n" HIR "被$N" HIR "罡劲所逼，一时无力作出抵挡，竟呆立当场。\n" NOR"]}, "damage_formula": %{"formula": "ap / 2 + random(jia * 5)"}, "hit_formula": %{"left_side": "ap * 2 / 3 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}, {"neili", "-600"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-600"}], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["me->start_busy(1);", "if (random(5) < 2 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(6));"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1);
      #   - if (random(5) < 2 && ! target->is_busy())
      #   - target->start_busy(1);
      #   - me->start_busy(1 + random(6));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
