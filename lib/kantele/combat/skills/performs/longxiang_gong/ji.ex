defmodule Kantele.Combat.Skills.Performs.LongxiangGong.Ji do
  @moduledoc """
  perform「般若极」（source longxiang-gong/ji.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "unarmed"}, {"dp", "parry"}, {"layer", "longxiang-gong"}], "level_gates": [{"longxiang-gong", "300"}], "map_gates": [{"force", "longxiang-gong"}, {"unarmed", "longxiang-gong"}], "prepared_gates": [{"unarmed", "longxiang-gong"}], "resource_gates": [{"max_neili", "5000"}, {"neili", "800"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的龙象般若功修为不够，难以施展", "你的内力修为不足，难以施展", "你没有激发龙象般若功为拳脚，难以施展", "你没有激发龙象般若功为内功，难以施展", "你没有准备使用龙象般若功，难以施展", "你现在的真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("unarmed") +
      #                me->query_skill("force")", "dp_formula": "target->query_skill("parry") +
      #                target->query_skill("force")"}, "buff_delete": ["shield"], "color_codes": ["CYN", "HIR", "HIW", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["= HIW "$N" HIW "罡气涌至，竟然激起层层气浪，顿时将$n"
      #                                  HIW "的护体真气摧毁得荡然无存！\n" NOR", "= CYN "可是$p" CYN "识破了$P"
      #                          CYN "这一招，斜斜一跃避开。\n" NOR"], "success": ["HIY "$N" HIY "运转龙象般若功第" + chinese_number(layer) + "层"
      #                 "功力，双拳携着『" HIR "十龙十象" HIY "』之力朝$n" HIY "崩击"
      #                 "\n而出，拳锋过处，竟卷起万里尘埃，正是密宗绝学「" HIW "般若"
      #                 "极" HIY "」。\n" NOR", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 80,
      #                                                  HIR "$n" HIR "不及闪避，顿被$N" HIR
      #                                                  "双拳击个正中，般若罡劲破体而入，尽"
      #                                                  "伤三焦六脉。\n" NOR)"]}, "damage_formula": %{"formula": "ap / 2 + random(jia * 5)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-400"}, {"neili", "-600"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-400"}, {"neili", "-600"}], "affect_by": [], "apply_adds": ["armor"], "busy_lines": ["me->start_busy(4);", "me->start_busy(4);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(4);
      #   - me->start_busy(4);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
