defmodule Kantele.Combat.Skills.Performs.TieZhang.Yin do
  @moduledoc """
  perform「阴阳磨」（source tie-zhang/yin.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "strike"}, {"dd", "dodge"}, {"dp", "parry"}, {"lvl", "strike"}], "level_gates": [{"force", "300"}, {"tie-zhang", "220"}], "map_gates": [{"strike", "tie-zhang"}], "prepared_gates": [{"strike", "tie-zhang"}], "resource_gates": [{"max_neili", "3500"}, {"neili", "500"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"affect_by_callbacks": [%{"buff_name": "tiezhang_yin", "duration_formula": "lvl / 50 + random(lvl / 50)", "id_formula": "me->query("id")", "level_formula": "me->query("jiali") + random(me->query("jiali") / 2)"}, %{"buff_name": "tiezhang_yang", "duration_formula": "lvl / 50 + random(lvl / 50)", "id_formula": "me->query("id")", "level_formula": "me->query("jiali") + random(me->query("jiali") / 2)"}], "all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你铁掌掌法火候不够，难以施展", "你没有激发铁掌掌法，难以施展", "你没有准备铁掌掌法，难以施展", "你的内功修为不够，难以施展", "你的内力修为不够，难以施展", "你现在的真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("strike") + me->query("str") * 5", "dp_formula": "target->query_skill("parry") + target->query("con") * 5"}, "callback_functions": [%{"body": "int lvl;
      #           lvl = me->query_skill("strike");
      #   
      #           target->affect_by("tiezhang_yin",
      #                          ([ "level" : me->query("jiali") + random(me->query("jiali") / 2),
      #                     ", "name": "finala", "params": "object me, object target, int damage", "return_type": "string"}, %{"body": "int lvl;
      #           lvl = me->query_skill("strike");
      #   
      #           target->affect_by("tiezhang_yang",
      #                          ([ "level" : me->query("jiali") + random(me->query("jiali") / 2),
      #                    ", "name": "finalb", "params": "object me, object target, int damage", "return_type": "string"}], "color_codes": ["CYN", "HIR", "HIW", "NOR"], "combat_exp_formulas": [{"lvl", "to_int(pow(to_float(me->query("combat_exp") * 10), 1.0 / 3))"}], "combat_messages": %{"fail": [], "other": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 55,
      #                                              (: finala, me, target :))", "= CYN "$n" CYN "见$N" CYN "掌出如风，心知"
      #                          "此招后着极是凌厉，当即斜跳闪开。\n" NOR", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 70,
      #                                              (: finalb, me, target :))", "= CYN "$n" CYN "忽闻呼啸声大至，眼见$N" CYN
      #                          "掌势如虹，急忙纵跃躲避开来。\n" NOR"], "success": ["HIW "$N" HIW "施出铁掌绝技「" HIR "阴阳磨"
      #                 HIW "」，左掌不着半点力道，携着阴寒劲向$n"
      #                 HIW "拂去。\n" NOR", "= HIR "\n紧接着$N" HIR "右掌一振，掌风过处，竟席"
      #                  "卷起一股热浪，向$n" HIR "胸前猛然拍落。\n" NOR"]}, "damage_formula": %{"formula": "ap / 2 + random(ap / 2)"}, "do_damage_calls": [%{"attack_type": "UNARMED_ATTACK", "callback": "finala", "damage_factor": 55, "damage_var": "damage"}, %{"attack_type": "UNARMED_ATTACK", "callback": "finalb", "damage_factor": 70, "damage_var": "damage"}], "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-400"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-400"}], "affect_by": ["tiezhang_yang", "tiezhang_yin"], "apply_adds": [], "busy_lines": ["me->start_busy(3 + random(3));"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3 + random(3));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
