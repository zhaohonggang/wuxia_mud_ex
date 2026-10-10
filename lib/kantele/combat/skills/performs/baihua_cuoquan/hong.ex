defmodule Kantele.Combat.Skills.Performs.BaihuaCuoquan.Hong do
  @moduledoc """
  perform「战神轰天诀」（source baihua-cuoquan/hong.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "unarmed"}, {"dp", "parry"}], "level_gates": [{"baihua-cuoquan", "250"}, {"zhanshen-xinjing", "250"}], "map_gates": [{"force", "zhanshen-xinjing"}, {"unarmed", "baihua-cuoquan"}], "prepared_gates": [{"unarmed", "baihua-cuoquan"}], "resource_gates": [{"max_neili", "5000"}, {"neili", "800"}], "var_gates": [{"damage", "0"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的百花错拳不够娴熟，难以施展", "你的战神心经修为不够，难以施展", "你的内力修为不足，难以施展", "你没有激发百花错拳，难以施展", "你没有激发战神心经，难以施展", "你没有准备百花错拳，难以施展", "你的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("unarmed") +
      #                me->query_skill("force")", "dp_formula": "target->query_skill("parry") +
      #                target->query_skill("dodge")"}, "color_codes": ["CYN", "HIR", "HIW", "HIY", "NOR", "RED"], "combat_exp_formulas": [{"lvls", "to_int(pow(to_float(me->query("combat_exp") * 10), 1.0 / 3))"}], "combat_messages": %{"fail": [], "other": ["HIW "$N" HIW "一声怒嚎，将战神心经提运极至，双拳顿时携着"
      #                 "雷霆万钧之势猛贯向$n" HIW "。\n" NOR", "= CYN "可是$p" CYN "识破了$P"
      #                          CYN "这一招，斜斜一跃避开。\n" NOR"], "success": ["= HIR "只见$N" HIR "一拳轰至，便将$n" HIR "震得"
      #                                  "心脉俱碎，仰天喷出一口鲜血，软软瘫倒。\n" NOR
      #                                  "( $n" RED "受伤过重，已经有如风中残烛，随时都"
      #                                  "可能断气。" NOR ")\n"", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 150,
      #                                                  HIR "结果$p" HIR "闪避不及，$P" HIR "的"
      #                                                      "拳力掌劲顿时透体而入，口中鲜血狂喷，连"
      #                                                      "退数步。\n" NOR)"]}, "damage_formula": %{"formula": "0"}, "hit_formula": %{"left_side": "ap * 3 / 5 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}, {"neili", "-150"}, {"neili", "-400"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-150"}, {"neili", "-400"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(4);", "me->start_busy(5);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(4);
      #   - me->start_busy(5);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
