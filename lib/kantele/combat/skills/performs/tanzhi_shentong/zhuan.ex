defmodule Kantele.Combat.Skills.Performs.TanzhiShentong.Zhuan do
  @moduledoc """
  perform「转乾坤」（source tanzhi-shentong/zhuan.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "finger"}, {"count", "mathematics"}, {"dp", "force"}], "level_gates": [{"qimen-wuxing", "200"}, {"tanzhi-shentong", "220"}], "map_gates": [{"finger", "tanzhi-shentong"}], "prepared_gates": [{"finger", "tanzhi-shentong"}], "resource_gates": [{"max_neili", "3500"}, {"neili", "800"}], "var_gates": [{"damage", "0"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的弹指神通不够娴熟，难以施展", "你的奇门五行修为不够，难以施展", "你没有激发弹指神通，难以施展", "你没有准备弹指神通，难以施展", "你的内力修为不足，难以施展", "你现在的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("finger") +
      #                me->query_skill("qimen-wuxing", 1) +
      #                me->query_skill("tanzhi-shentong", 1)", "dp_formula": "target->query_skill("force") +
      #                target->query_skill("parry", 1) +
      #                target->query_skill("qimen-wuxing", 1)"}, "color_codes": ["CYN", "HIC", "HIR", "HIW", "NOR", "RED"], "combat_exp_formulas": [{"lvls", "to_int(pow(to_float(me->query("combat_exp") * 10), 1.0 / 3))"}], "combat_messages": %{"fail": [], "other": ["= CYN "$p" CYN "见$P" CYN "招式奇特，不感大"
      #                          "意，顿时向后跃数丈，躲闪开来。\n" NOR"], "success": ["HIC "$N" HIC "将全身功力聚于一指，指劲按照二十八宿方位云贯而出，正"
      #                 "是桃花岛「" HIR "转乾坤" HIC "」绝技。\n" NOR", "= HIR "霎那间$n" HIR "只见寒芒一闪，$N" HIR "食指"
      #                                  "已钻入$p" HIR "印堂半尺，指劲顿时破脑而入。\n"
      #                                  HIW "你听到“噗”的一声，身上竟然溅到几滴脑浆！"
      #                                  "\n" NOR "( $n" RED "受伤过重，已经有如风中残烛"
      #                                  "，随时都可能断气。" NOR ")\n"", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, (100 + random(count/10)),
      #                                                  HIR "霎那间$n" HIR "只见寒芒一闪，$N"
      #                                                      HIR "食指已钻入$p" HIR "胸堂半尺，指劲"
      #                                                      "顿时破体而入。\n你听到“嗤”的一声，"
      #                                                      "身上竟然溅到几滴鲜血！\n" NOR)"]}, "damage_formula": %{"formula": "0"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-(200 + random(count))"}, {"neili", "-200"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-200"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);", "me->start_busy(2);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(3);
      #   - me->start_busy(2);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
