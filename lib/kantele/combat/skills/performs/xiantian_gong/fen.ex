defmodule Kantele.Combat.Skills.Performs.XiantianGong.Fen do
  @moduledoc """
  perform「五阴焚灭」（source xiantian-gong/fen.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "unarmed"}, {"dp", "parry"}], "level_gates": [{"xiantian-gong", "240"}], "map_gates": [{"force", "xiantian-gong"}, {"unarmed", "xiantian-gong"}], "prepared_gates": [{"unarmed", "xiantian-gong"}], "resource_gates": [{"max_neili", "4000"}, {"neili", "600"}], "var_gates": [{"damage", "0"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的先天功修为不够，难以施展", "你的内力修为不足，难以施展", "你没有激发先天功为拳脚，难以施展", "你没有激发先天功为内功，难以施展", "你没有准备使用先天功，难以施展", "你现在的真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("unarmed") +
      #                me->query_skill("force")", "dp_formula": "target->query_skill("parry") +
      #                target->query_skill("force")"}, "color_codes": ["CYN", "HIR", "HIW", "NOR", "RED"], "combat_messages": %{"fail": [], "other": ["HIW "$N" HIW "体内先天真气急速运转，单掌一抖，掌心顿时升起一个气"
      #                 "团，朝$n" HIW "猛拍而去。\n" NOR", "= CYN "可是$p" CYN "识破了$P"
      #                          CYN "这一招，斜斜一跃躲避开来。\n" NOR"], "success": ["= HIR "$n" HIR "正直诧异间，$N" HIR "一掌已正中$p"
      #                                  HIR "脑门，先天真气登时贯脑而入。\n" NOR "( $n"
      #                                  RED "受伤过重，已经有如风中残烛，随时都可能断气"
      #                                  "。" NOR ")\n"", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 90,
      #                                                  HIR "结果$N" HIR "这掌正中$n" HIR "胸"
      #                                                      "口，先天真气登时透体而入，接连喷出数"
      #                                                      "口鲜血。\n" NOR)"]}, "damage_formula": %{"formula": "0"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-120"}, {"neili", "-500"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-120"}, {"neili", "-500"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);", "me->start_busy(4);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(3);
      #   - me->start_busy(4);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
