defmodule Kantele.Combat.Skills.Performs.NeverDefeated.Wanli do
  @moduledoc """
  perform「wanli」（source never-defeated/wanli.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "never-defeated"}, {"damage", "force"}, {"dp", "parry"}], "level_gates": [{"never-defeated", "120"}], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["晴空万里只能对战斗中的对手使用。\n", "你的不败神功还不够娴熟，不能使用晴空万里。\n", "你现在内力太弱，不能使用晴空万里。\n", "你必须手持兵刃才能施展晴空万里！\n", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("never-defeated", 1) * 3 / 2 +
      #                me->query_skill("martial-cognize", 1)", "dp_formula": "target->query_skill("parry") +
      #                target->query_skill("martial-cognize", 1)"}, "color_codes": ["CYN", "HIC", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["HIC "$N" HIC "怀抱" + weapon->name() + HIC "，一"
      #                 "圈圈的划向$n" HIC "，将$p" HIC "卷在当中！\n" NOR", "= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50, pmsg)", "= CYN "可是$p" CYN "看破了$P"
      #                          CYN "的变化，见招拆招，没有受到任何伤害。\n"NOR"], "success": ["HIR "$n连忙腾挪躲闪，然而“扑哧”一声，" + weapon->name() +
      #                  HIR "正好击中$p" HIR "的" + limb + "，$p"
      #                  HIR "一声惨叫，连退数步。\n" NOR"]}, "damage_formula": %{"formula": "ap + (int)me->query_skill("force")"}, "hit_formula": %{"left_side": "ap / 2 + random(ap * 2)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-180"}, {"neili", "-20"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-180"}, {"neili", "-20"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "target->start_busy(1 + random(3));", "me->start_busy(2);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - target->start_busy(1 + random(3));
      #   - me->start_busy(2);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
