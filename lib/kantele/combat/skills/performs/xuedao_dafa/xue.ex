defmodule Kantele.Combat.Skills.Performs.XuedaoDafa.Xue do
  @moduledoc """
  perform「祭血神刀」（source xuedao-dafa/xue.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "blade"}, {"dp", "parry"}], "level_gates": [{"force", "220"}, {"xuedao-dafa", "160"}], "map_gates": [{"blade", "xuedao-dafa"}, {"force", "xuedao-dafa"}], "prepared_gates": [], "resource_gates": [{"neili", "200"}, {"qi", "100"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你的内功火候不够，难以施展", "你的血刀大法还不到家，难以施展", "你没有激发血刀大法为内功，难以施展", "你没有激发血刀大法为刀法，难以施展", "你目前气血翻滚，难以施展", "你目前真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("blade")", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["CYN", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["= CYN "可是$n" CYN "侧身避让，不慌不忙，躲过了$N"
      #                          CYN "的必杀一刀。\n"NOR"], "success": ["HIR "$N" HIR "挥刀向左肩一勒，血珠顿时溅满刀面，紧接着右臂"
      #                 "抡出一片血光向$n" HIR "当头劈落。\n" NOR", "= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 80,
      #                                              HIR "$n" HIR "只见血刀疾闪，眼前一阵血"
      #                                              "红，刀刃劈面而下，鲜血飞溅，不禁惨声"
      #                                              "大嚎！\n" NOR)"]}, "damage_formula": %{"formula": "ap + random(ap / 2)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "receive_damage_calls": [%{"formula": "50", "kind": "wound", "part": "qi", "source": None}], "resource_adds": [{"neili", "-100"}, {"neili", "-150"}], "resource_queries": ["neili", "qi"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}, "weapon_type": "blade"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-150"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(2);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(2);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
