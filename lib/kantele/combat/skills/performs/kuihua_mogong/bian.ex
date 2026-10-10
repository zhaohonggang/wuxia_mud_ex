defmodule Kantele.Combat.Skills.Performs.KuihuaMogong.Bian do
  @moduledoc """
  perform「无边无际」（source kuihua-mogong/bian.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "kuihua-mogong"}, {"dp", "martial-cognize"}], "level_gates": [{"kuihua-mogong", "260"}], "map_gates": [{"sword", "kuihua-mogong"}], "prepared_gates": [{"unarmed", "kuihua-mogong"}], "resource_gates": [{"max_neili", "3700"}, {"neili", "300"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你手里拿的不是剑，怎么施", "你并没有准备使用葵", "你的葵花魔功不够娴熟，难以施展", "你的内力修为不足，难以施展", "你现在的真气不足，难以施展", "你没有准备使用葵花魔功，难以施展", "你没有准备使用葵花魔功，难以施展", "对方都已经这样了，用不着这么费力吧？\n", "对方现在已经无法控制真气，放胆攻击吧。\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("kuihua-mogong", 1) +
      #                me->query_skill("dodge")", "dp_formula": "target->query_skill("martial-cognize", 1) +
      #                target->query_skill("dodge")"}, "buff_delete": ["no_perform"], "callback_functions": [%{"body": "target->set_temp("no_perform", 1);
      #           call_out("bian_end", 10 + random(ap / 30), me, target);
      #           return HIR "$n" HIR "只觉眼前无数寒光闪过，随即全身一阵"
      #                  "刺痛，几股血柱自身上射出。\n$p陡然间一提真气，"
      #             ", "name": "final", "params": "object me, object target, int ap", "return_type": "string"}, %{"body": "if (target && target->query_temp("no_perform"))
      #           {
      #                   if (living(target))
      #                   {
      #                           message_combatd(HIC "$N" HIC "深深吸入一口"
      #                             ", "name": "bian_end", "params": "object me, object target", "return_type": "void"}], "color_codes": ["CYN", "HIC", "HIG", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["= COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, 90,
      #                                             (: final, me, target, damage :))", "= CYN "$n" CYN "大惊之下全然无法招架，急忙"
      #                          "抽身急退数尺，躲开了这一招。\n" NOR"], "success": ["HIR "$N" HIR "一声尖啸，身体猛然旋转不定，" + name +
      #                 HIR "顿时化成无数气流，犹如千万根银针，齐齐卷向$n" HIR "！\n" NOR"]}, "damage_formula": %{"formula": "ap + random(ap)"}, "do_damage_calls": [%{"attack_type": "REMOTE_ATTACK", "callback": "final", "damage_factor": 90, "damage_var": "damage"}], "hit_formula": %{"left_side": "ap * 3 / 5 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-150"}, {"neili", "-200"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-150"}, {"neili", "-200"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": ["no_perform"]}
      #   - me->start_busy(2);
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
