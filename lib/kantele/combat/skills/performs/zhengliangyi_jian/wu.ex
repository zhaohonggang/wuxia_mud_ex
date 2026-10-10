defmodule Kantele.Combat.Skills.Performs.ZhengliangyiJian.Wu do
  @moduledoc """
  perform「无声无色」（source zhengliangyi-jian/wu.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "sword"}, {"dp", "parry"}], "level_gates": [{"dodge", "220"}, {"zhengliangyi-jian", "160"}], "map_gates": [{"sword", "zhengliangyi-jian"}], "prepared_gates": [], "resource_gates": [{"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "在这里不能攻击他人。\n", "在这里不能攻击他人。\n", "你打算攻击自己？\n", "你使用的武器不对，无法施展", "你的正两仪剑法不够娴熟，难以施展", "你的轻功火候不足，难以施展", "你现在身法太差，难以施展", "你现在真气不够，难以施展", "你没有激发正两仪剑法，难以施展", "对方正被官府保护着呢，还是别去招惹。\n", "比武的时候最好是正大光明的较量。\n", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("sword")", "dp_formula": "target->query_skill("parry")"}, "callback_functions": [%{"body": "object weapon;
      #           weapon = me->query_temp("weapon");
      #   
      #           return  HIW "结果$n" HIW "并没有察觉$N" HIW "的杀意，丝毫没把"
      #                   "这一招放在心上，只\n是身子略微的向前一倾。\n" NOR +
      #                   HIR "霎时只见$N" HIR "招数", "name": "final", "params": "object me, object target, int damage", "return_type": "string"}], "color_codes": ["HIC", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "$N" HIW "一声阴笑，突然使出一招「无声无色」，疾向$n"
      #                 HIW "背后刺去。\n" NOR", "= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 30,
      #                                              (: final, me, target, damage :))", "= HIC "可是$p" HIC "看破了$P" HIC "的企图，飞身"
      #                          "一跃而起，将$P" HIC "这招化解于无形。\n" NOR"], "success": []}, "damage_formula": %{"formula": "ap * 2 / 3 + random(ap / 3)"}, "do_damage_calls": [%{"attack_type": "WEAPON_ATTACK", "callback": "final", "damage_factor": 30, "damage_var": "damage"}], "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-200"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": false, "requires_living": true, "uses_offensive_target": false}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-200"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
