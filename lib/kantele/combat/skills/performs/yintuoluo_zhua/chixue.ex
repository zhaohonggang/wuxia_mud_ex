defmodule Kantele.Combat.Skills.Performs.YintuoluoZhua.Chixue do
  @moduledoc """
  perform「赤血连环爪」（source yintuoluo-zhua/chixue.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "claw"}, {"dp", "parry"}, {"lvl", "yintuoluo-zhua"}], "level_gates": [{"force", "300"}, {"yintuoluo-zhua", "200"}], "map_gates": [{"claw", "yintuoluo-zhua"}, {"force", "hunyuan-yiqi"}, {"force", "luohan-fumogong"}, {"force", "yijinjing"}], "prepared_gates": [{"claw", "yintuoluo-zhua"}], "resource_gates": [{"neili", "500"}], "var_gates": [{"i", "4"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你现在没有激发少林内功为内功，难以施展", "你因陀罗爪不够娴熟，难以施展", "你没有激发因陀罗爪，难以施展", "你没有准备因陀罗爪，难以施展", "你的内功修为不够，难以施展", "你现在的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("claw") + me->query_skill("force") + me->query_str() + me->query_dex()", "dp_formula": "target->query_skill("parry") + target->query_skill("force") + target->query_str() + target->query_dex()"}, "color_codes": ["CYN", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": ["= CYN "$n" CYN "奋力招架，竟将$N" CYN "这招化解。\n" NOR"], "other": [], "success": ["HIW "\n$N" HIW "运转少林真气，双手忽成爪行，施出绝招「" HIR "赤"
      #                 "血连环爪" HIW "」，迅猛无比地抓向$n" HIW "。\n" NOR", "= HIR "$n" HIR "全身一颤，立足不稳，被$N" HIR "这一爪抓得跌落在地上。\n" NOR", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 120,
      #                                          HIR "但见$N" HIR "双爪划过，$n" HIR "已闪避不及，胸口被$N" HIR
      #                                              "抓出十条血痕。\n" NOR)"]}, "damage_formula": %{"formula": "ap + random(ap)"}, "hit_formula": %{"left_side": "ap * 3 / 4 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}, {"neili", "-400"}, {"neili", "-500"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-400"}, {"neili", "-500"}], "affect_by": [], "apply_adds": ["attack", "unarmed_damage"], "busy_lines": ["me->start_busy(3);", "me->start_busy(3);", "//target->start_busy(lvl/30);", "me->start_busy(4);", "if (random(8) < 2 && !target->is_busy())", "target->start_busy(1);"], "remote_damage": true, "set_flags": [{"eff_jing", "0"}, {"eff_qi", "0"}], "temp_set": []}
      #   - me->start_busy(3);
      #   - me->start_busy(3);
      #   - //target->start_busy(lvl/30);
      #   - me->start_busy(4);
      #   - if (random(8) < 2 && !target->is_busy())
      #   - target->start_busy(1);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
