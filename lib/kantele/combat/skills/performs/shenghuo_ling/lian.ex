defmodule Kantele.Combat.Skills.Performs.ShenghuoLing.Lian do
  @moduledoc """
  perform「敛心令」（source shenghuo-ling/lian.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "sword"}, {"dp", "parry"}, {"skill", "shenghuo-ling"}], "level_gates": [], "map_gates": [{"sword", "shenghuo-ling"}], "prepared_gates": [], "resource_gates": [{"max_neili", "1600"}, {"neili", "350"}], "var_gates": [{"skill", "150"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的兵器不对，不能使用圣火令法之", "你的圣火令法等级不够, 不能使用圣火令法之", "你的内力修为不足，不能使用圣火令法之", "你的内力不够，不能使用圣火令法之", "你没有激发圣火令法，不能使用圣火令法之", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("sword")", "dp_formula": "target->query_skill("parry")"}, "callback_functions": [%{"body": "target->receive_damage("jing", damage / 2);
      #          target->receive_wound("jing", damage / 4);
      #          target->start_busy(1);
      #   
      #          return HIR "$n" HIR "只见眼前寒光颤动，突"
      #                 "然$N" HIR "双手出现在自己眼前，", "name": "final", "params": "object me, object target, int damage", "return_type": "string"}], "color_codes": ["CYN", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "$N" HIW "一个筋斗猛翻至$n" HIW "跟前，陡然使出圣火"
      #                 "令法之敛心令，手中" + weapon->name() + NOR + HIW "忽伸"
      #                 "忽缩，招式诡异无比。\n" NOR", "= COMBAT_D->do_damage(me, target, REMOTE_ATTACK,                
      #                          damage, 0, (: final, me, target, damage :))", "= CYN "$n" CYN "见眼前寒光颤动，连忙振作精神勉强"
      #                         "抵挡，向后疾退数步，好不容易闪在了$N" CYN "攻"
      #                         "击范围之外。\n" NOR"], "success": []}, "damage_formula": %{"formula": "skill / 2 + random(skill)"}, "do_damage_calls": [%{"attack_type": "REMOTE_ATTACK", "callback": "final", "damage_factor": 0, "damage_var": "damage"}], "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "receive_damage_calls": [%{"formula": "damage / 2", "kind": "damage", "part": "jing", "source": None}, %{"formula": "damage / 4", "kind": "wound", "part": "jing", "source": None}], "resource_adds": [{"neili", "-100"}, {"neili", "-300"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-300"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(3);", "me->start_busy(4);", "target->start_busy(1);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3);
      #   - me->start_busy(4);
      #   - target->start_busy(1);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
