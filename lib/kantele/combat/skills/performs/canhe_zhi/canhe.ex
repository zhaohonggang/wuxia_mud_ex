defmodule Kantele.Combat.Skills.Performs.CanheZhi.Canhe do
  @moduledoc """
  perform「参合剑气」（source canhe-zhi/canhe.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "finger"}, {"clv", "canhe-zhi"}, {"damage", "finger"}, {"dp", "dodge"}, {"dp", "force"}, {"dp", "parry"}, {"slv", "liumai-shenjian"}], "level_gates": [{"canhe-zhi", "220"}, {"force", "320"}], "map_gates": [], "prepared_gates": [{"finger", "canhe-zhi"}], "resource_gates": [{"max_neili", "6000"}, {"neili", "900"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你必须空手才能使用", "你的参合指修为有限，难以施展", "你现在没有准备使用参合指，难以施展", "你的内功修为太差，难以施展", "你的内力修为不足，难以施展", "你的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("finger")", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["CYN", "HIR", "HIW", "HIY", "NOR"], "combat_exp_formulas": [{"lvl", "to_int(pow(to_float(me->query("combat_exp") * 10), 1.0 / 3))"}], "combat_messages": %{"fail": [], "other": ["HIW "只见$N" HIW "十指分摊，霎时破空声骤响，数股剑气至指尖激"
      #                 "射而出，朝$n" HIW "径直奔去！\n" NOR", "= "( $N" + eff_status_msg(p) + ")\n"", "= CYN "\n$n" CYN "见$N" CYN "来势汹涌，急忙飞身一跃而"
      #                          "起，避开了这一击。\n" NOR", "= "( $N" + eff_status_msg(p) + ")\n"", "= CYN "\n$n" CYN "见$N" CYN "来势汹涌，急忙飞身一跃而"
      #                          "起，避开了这一击。\n" NOR", "= "( $N" + eff_status_msg(p) + ")\n"", "= CYN "\n$n" CYN "见$N" CYN "来势汹涌，急忙飞身一跃而"
      #                          "起，避开了这一击。\n" NOR"], "success": ["= HIY "\n但见$n" HIY "斜斜一指点出，指出如风，剑气纵横，嗤然"
      #                          "作响，竟将$N" HIY "的剑气全部折回，反向自己射去！\n" NOR +
      #                          HIR "你听到「嗤啦」一声轻响，脸上竟溅到一些血滴！\n" NOR", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 64,
      #                                              HIR "\n顿时只听“嗤啦”的一声，$n" HIR
      #                                              "躲闪不及，剑气顿时穿胸而过，带出一蓬"
      #                                              "血雨。\n" NOR)", "= HIY "\n忽见$n" HIY "左手小指一伸，一招「少泽剑」至指尖透出"
      #                          "，真气鼓荡，轻灵迅速，顿将$N" HIY "剑气逼回！\n" NOR + HIR
      #                          "你听到「嗤啦」一声轻响，脸上竟溅到一些血滴！\n" NOR", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 75,
      #                                              HIR "\n只听$n" HIR "一声惨嚎，被$N" HIR
      #                                              "的剑气刺中了要害，血肉模糊，鲜血迸流不"
      #                                              "止。\n" NOR)", "= HIY "\n可电光火石之间，$n" HIY "猛然翻掌，右手陡然探出，中"
      #                          "指「中冲剑」向$N" HIY "一竖，登将参合剑气化于无形！\n" NOR
      #                          + HIR "你听到「嗤啦」一声轻响，脸上竟溅到一些血滴！\n" NOR", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 100,
      #                                              HIR "\n$n" HIR "奋力招架，仍是不敌，$N"
      #                                              "的" HIR "无形剑气已透体而入，鲜血飞射"
      #                                              "，无力再战。\n" NOR)"]}, "damage_formula": %{"formula": "me->query_skill("finger") + me->query_skill("force")"}, "hit_formula": %{"left_side": "ap * 3 / 4 + random(ap)", "operator": ">", "right_side": "dp"}, "receive_damage_calls": [%{"formula": "slv / 3 + random(slv / 4)", "kind": "wound", "part": "qi", "source": "target"}, %{"formula": "slv / 2 + random(slv / 4)", "kind": "wound", "part": "qi", "source": "target"}, %{"formula": "slv / 2 + random(slv / 2)", "kind": "wound", "part": "qi", "source": "target"}], "resource_adds": [{"neili", "-400 - random(100)"}], "resource_queries": ["max_neili", "max_qi", "neili", "qi"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(3 + random(3));", "&&! target->is_busy()", "&&! target->is_busy()", "&&! target->is_busy()", "me->start_busy(6);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3 + random(3));
      #   - &&! target->is_busy()
      #   - &&! target->is_busy()
      #   - &&! target->is_busy()
      #   - me->start_busy(6);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
