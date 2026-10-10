defmodule Kantele.Combat.Skills.Performs.XiantianGong.Dang do
  @moduledoc """
  perform「神威浩荡」（source xiantian-gong/dang.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "unarmed"}, {"dp", "parry"}], "level_gates": [{"xiantian-gong", "240"}], "map_gates": [{"force", "xiantian-gong"}, {"unarmed", "xiantian-gong"}], "prepared_gates": [{"unarmed", "xiantian-gong"}], "resource_gates": [{"max_neili", "4000"}, {"neili", "800"}, {"stable", "100"}], "var_gates": [{"damage", "0"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的先天功修为不够，难以施展", "你的内力修为不足，难以施展", "你没有激发先天功为拳脚，难以施展", "你没有激发先天功为内功，难以施展", "你没有准备使用先天功，难以施展", "你现在的真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("unarmed") +
      #                me->query_skill("force")", "dp_formula": "target->query_skill("parry") +
      #                target->query_skill("force")"}, "color_codes": ["CYN", "HIR", "HIW", "NOR", "RED"], "combat_messages": %{"fail": [], "other": ["HIW "只见$N" HIW "双目精光四射，双掌陡然一振，将体内积蓄的"
      #                 "先天真气云贯推出，顿时呼啸\n声大作，先天劲道层层叠叠，宛如"
      #                 "涛浪般涌向$n" HIW "。\n" NOR", "= HIW "只听“锵”的一声脆响，$n" HIW "手"
      #                                          "中的" + wp + HIW "在$N" HIW "内力激荡"
      #                                          "下应声而碎，脱手跌落在地上。\n" NOR", "= HIW "只听“轰”的一声闷响，$n" HIW "身"
      #                                          "着的" + cl + HIW "在$N" HIW "内力激荡"
      #                                          "下应声而裂，化成一块块碎片。\n" NOR", "= HIW "只听“轰”的一声闷响，$n" HIW "身"
      #                                          "着的" + cl + HIW "在$N" HIW "内力激荡"
      #                                          "下应声而碎，化成一块块碎片。\n" NOR", "= CYN "可是$p" CYN "知道$P" CYN "这招的厉"
      #                          "害，不敢硬接，当即斜跃躲避开来。\n" NOR"], "success": ["= HIR "便在$n" HIR "微微一愣间，$N" HIR "罡风已然"
      #                                  "及体，$p" HIR "一声哀嚎，全身骼络尽数断裂。\n"
      #                                  NOR "( $n" RED "受伤过重，已经有如风中残烛，随"
      #                                  "时都可能断气。" NOR ")\n"", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK,
      #                                                      damage, 90, HIR "$N" HIR "的"
      #                                                      "罡劲登时瓦解了$n" HIR "的护"
      #                                                      "体真气，$p" HIR "真元受损，"
      #                                                      "接连喷出数口鲜血。\n" NOR)"]}, "damage_formula": %{"formula": "0"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-120"}, {"neili", "-150"}, {"neili", "-400"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-120"}, {"neili", "-150"}, {"neili", "-400"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);", "me->start_busy(4);"], "remote_damage": true, "set_flags": [{"consistence", "0"}], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(3);
      #   - me->start_busy(4);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
