defmodule Kantele.Combat.Skills.Performs.KuihuaMogong.Qiong do
  @moduledoc """
  perform「无穷无尽」（source kuihua-mogong/qiong.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "kuihua-mogong"}, {"ap1", "kuihua-mogong"}, {"dp1", "dodge"}], "level_gates": [{"kuihua-mogong", "250"}], "map_gates": [{"sword", "kuihua-mogong"}], "prepared_gates": [{"unarmed", "kuihua-mogong"}], "resource_gates": [{"max_neili", "3800"}, {"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的葵花魔功还不够娴熟，不能使用", "你的内力修为不足，难以施展", "你的真气不够，无法施展", "你手里拿的不是剑，怎么施", "你并没有准备使用葵", "你没有准备使用葵花魔功，难以施展", "你没有准备使用葵花魔功，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("kuihua-mogong", 1)", "dp_formula": "target->query("combat_exp") / 10000"}, "color_codes": ["HIC", "HIM", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["= HIC "$n" HIC "知道来招不善，急忙闪避，没出一点差错。\n" NOR", "= HIM "$n" HIM "大吃一惊，连忙退后，居然"
      #                         "侥幸躲开着这一招！\n" NOR"], "success": ["HIR "\n$N" HIR "尖啸一声，猛然进步欺前，一招竟直袭$n" HIR "要害，速度之快，令"
      #                 "人见所未见，闻所未闻。\n" NOR", "= COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, 95 + random(5),
      #                                                   HIR "这一招速度之快完全超出了$n" HIR "的想象，$n" HIR
      #                                                   "慌忙回缩招架，但是此招之快，已无从躲闪，$n" HIR "尖叫"
      #                                                   "一声，已然中招。\n" NOR)", "= HIR "这一招速度之快完全超出了$n" HIR "的想象，被$N"
      #                          HIR "这一招正好击中了丹田要害，浑身真气登时涣散！\n" NOR"]}, "damage_formula": %{"formula": "ap / 2 + random(ap)"}, "exp_compare": [{"ap", "dp"}], "resource_adds": [{"neili", "-120"}, {"neili", "-60"}, {"neili", "-80"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-120"}, {"neili", "-60"}, {"neili", "-80"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(1 + random(2));"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1 + random(2));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
