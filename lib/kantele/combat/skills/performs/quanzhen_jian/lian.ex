defmodule Kantele.Combat.Skills.Performs.QuanzhenJian.Lian do
  @moduledoc """
  perform「三连环」（source quanzhen-jian/lian.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "sword"}, {"dp", "parry"}], "level_gates": [{"quanzhen-jian", "180"}], "map_gates": [{"strike", "chongyang-shenzhang"}, {"strike", "haotian-zhang"}, {"sword", "quanzhen-jian"}], "prepared_gates": [], "resource_gates": [{"neili", "400"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你手中无剑，如何施展", "你全真剑法不够娴熟，难以施展", "你没有激发全真剑法，难以施展", "你没有激发全真的掌法，难以施展", "你现在的真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("sword") + me->query_skill("unarmed", 1)", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["HIR", "HIW", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": [], "success": ["HIR "拆得数招，$N左剑平刺，右掌正击，同时左腿横扫而出，正是全真派中的" LIAN HIR"绝招。\n" NOR", "COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 70,
      #                                              HIR "只见$n躲闪不及，已经被$N一腿扫中，惨叫声中，向后跌出丈许。\n" NOR)"]}, "damage_formula": %{"formula": "ap / 2 + random(ap)"}, "resource_adds": [{"neili", "-150"}, {"neili", "-50"}, {"neili", "-60"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword", "wield_actions": ["unequip", "wield"]}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-150"}, {"neili", "-50"}, {"neili", "-60"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
