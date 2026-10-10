defmodule Kantele.Combat.Skills.Performs.SanyinWugongzhao.Zhua do
  @moduledoc """
  perform「三阴毒爪」（source sanyin-wugongzhao/zhua.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "claw"}, {"dp", "parry"}, {"lvl", "claw"}], "level_gates": [{"sanyin-wugongzhao", "80"}], "map_gates": [{"claw", "sanyin-wugongzhao"}], "prepared_gates": [{"claw", "sanyin-wugongzhao"}], "resource_gates": [{"neili", "150"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"affect_by_callbacks": [%{"buff_name": "sanyin", "duration_formula": "lvl / 40 + random(lvl / 40)", "id_formula": "me->query("id")", "level_formula": "me->query("jiali") + random(me->query("jiali"))"}], "all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的三阴蜈蚣爪不够娴熟，无法使用", "你没有激发三阴蜈蚣爪，无法使用", "你没有准备使用三阴蜈蚣爪，无法使用", "你真气不足，无法施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("claw")", "dp_formula": "target->query_skill("parry")"}, "callback_functions": [%{"body": "int lvl;
      #   
      #           lvl = me->query_skill("claw");
      #           target->affect_by("sanyin",
      #                          ([ "level" : me->query("jiali") + random(me->query("jiali")),
      #                             "id"", "name": "final", "params": "object me, object target", "return_type": "string"}], "color_codes": ["HIG", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 45,
      #                                              (: final, me, target :))"], "success": ["HIR "$N" HIR "突然一声怪叫，蓦的面赤如血，随即手腕一抖，抓向$n"
      #                 HIR "的要害。\n" NOR", "= HIR "不过$p" HIR "看破了$P" HIR "的招式，"
      #                          "凝神招架，挡住了$P" HIR "的毒招。\n" NOR"]}, "damage_formula": %{"formula": "ap / 2 + random(ap / 2)"}, "do_damage_calls": [%{"attack_type": "UNARMED_ATTACK", "callback": "final", "damage_factor": 45, "damage_var": "damage"}], "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": ["sanyin"], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(2);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(2);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
