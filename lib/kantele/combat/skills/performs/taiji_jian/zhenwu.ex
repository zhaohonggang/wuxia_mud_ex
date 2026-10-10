defmodule Kantele.Combat.Skills.Performs.TaijiJian.Zhenwu do
  @moduledoc """
  perform「真武除邪」（source taiji-jian/zhenwu.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "sword"}, {"dp", "parry"}], "level_gates": [{"taiji-jian", "180"}], "map_gates": [{"sword", "taiji-jian"}], "prepared_gates": [], "resource_gates": [{"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你的太极剑法不够娴熟，难以施展", "你现在真气不够，难以施展", "你没有激发太极剑法，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("sword")", "dp_formula": "target->query_skill("parry")"}, "callback_functions": [%{"body": "target->receive_damage("jing", damage / 4, me);
      #           target->receive_wound("jing", damage / 8, me);
      #           return  HIY "结果$n" HIY "却丝毫未把这招放在眼里，随手应了一招，却见$N"
      #                   HIY "剑势\n忽然一变，气象万千，变幻无穷，", "name": "final", "params": "object me, object target, int damage", "return_type": "string"}], "color_codes": ["HIC", "HIR", "HIY", "NOR"], "combat_exp_formulas": [{"lvl", "to_int(pow(to_float(me->query("combat_exp") * 10), 1.0 / 3))"}], "combat_messages": %{"fail": [], "other": ["HIY "$N" HIY "跨前一步，平平挥出一剑，横扫$n" HIY "而去，毫"
      #                 "无半点花巧可言。\n" NOR", "= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 85,
      #                                              (: final, me, target, damage :))", "= HIC "可是$n" HIC "看透$P" HIC "招后更有杀着，镇"
      #                          "定逾恒，全神应对自如。\n" NOR"], "success": []}, "damage_formula": %{"formula": "ap + random(ap / 3)"}, "do_damage_calls": [%{"attack_type": "WEAPON_ATTACK", "callback": "final", "damage_factor": 85, "damage_var": "damage"}], "hit_formula": %{"left_side": "ap * 3 / 5 + random(ap)", "operator": ">", "right_side": "dp"}, "receive_damage_calls": [%{"formula": "damage / 4", "kind": "damage", "part": "jing", "source": "me"}, %{"formula": "damage / 8", "kind": "wound", "part": "jing", "source": "me"}], "resource_adds": [{"neili", "-50"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-50"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
