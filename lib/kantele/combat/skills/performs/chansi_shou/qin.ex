defmodule Kantele.Combat.Skills.Performs.ChansiShou.Qin do
  @moduledoc """
  perform「缠丝擒拿」（source chansi-shou/qin.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "hand"}, {"dp", "parry"}, {"skill", "chansi-shou"}], "level_gates": [], "map_gates": [{"hand", "chansi-shou"}], "prepared_gates": [{"hand", "chansi-shou"}], "resource_gates": [{"neili", "100"}], "var_gates": [{"skill", "120"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你缠丝擒拿手等级不够，难以施展", "你没有激发缠丝擒拿手，难以施展", "你没有准备缠丝擒拿手，难以施展", "你现在的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("hand")", "dp_formula": "target->query_skill("parry")"}, "callback_functions": [%{"body": "string msg;
      #   
      #           msg = HIR "却见$n" HIR "奋力抵抗，可终究无法"
      #                 "摆脱$N" HIR "的攻势，连中数掌，";
      #   
      #           if (random(3) >= 1 && ! target->is_busy())
      #           {
      #                   target->start_busy(damage / 1", "name": "final", "params": "object me, object target, int damage", "return_type": "string"}], "color_codes": ["CYN", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "$N" HIW "悄然贴近$n" HIW "，施出缠丝擒拿，双手忽"
      #                 "折忽扭，或抓或甩，直琐$p" HIW "各处要脉。\n" NOR", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 35,
      #                                              (: final, me, target, damage :))", "= CYN "可是$n" CYN "的看破了$N"
      #                          CYN "的招式，巧妙的招架拆解，没露半点破绽。\n" NOR", "= "难以反击。\n" NOR", "= "鲜血狂喷。\n" NOR"], "success": ["HIR "却见$n" HIR "奋力抵抗，可终究无法"
      #                 "摆脱$N" HIR "的攻势，连中数掌，""]}, "damage_formula": %{"formula": "50 + ap / 6 + random(ap / 6)"}, "do_damage_calls": [%{"attack_type": "UNARMED_ATTACK", "callback": "final", "damage_factor": 35, "damage_var": "damage"}], "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-20"}, {"neili", "-80"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-20"}, {"neili", "-80"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);", "if (random(3) >= 1 && ! target->is_busy())", "target->start_busy(damage / 15);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(3);
      #   - if (random(3) >= 1 && ! target->is_busy())
      #   - target->start_busy(damage / 15);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
