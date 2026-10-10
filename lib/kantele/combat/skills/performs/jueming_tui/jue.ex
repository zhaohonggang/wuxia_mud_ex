defmodule Kantele.Combat.Skills.Performs.JuemingTui.Jue do
  @moduledoc """
  perform「绝命一踢」（source jueming-tui/jue.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "unarmed"}, {"dp", "dodge"}, {"pp", "parry"}], "level_gates": [{"jueming-tui", "80"}], "map_gates": [{"unarmed", "jueming-tui"}], "prepared_gates": [{"unarmed", "jueming-tui"}], "resource_gates": [{"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你绝命腿法不够娴熟，难以施展", "你没有激发绝命腿法，难以施展", "你没有准备绝命腿法，难以施展", "你目前的内力不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("unarmed") + me->query("str") * 10", "dp_formula": "target->query_skill("dodge") + target->query("dex") * 10"}, "color_codes": ["CYN", "HIC", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["= HIC "可是$n" HIC "身子一晃，硬生生架住了$N" HIC "这一腿。\n" NOR", "= CYN "却见$n" CYN "镇定的向后一纵，闪开了$N" CYN "这一腿。\n" NOR"], "success": ["HIR "只听$N" HIR "一声冷哼，侧身飞踢，右腿横"
      #                     "扫向$n" HIR "，当真是力不可挡。\n" NOR", "HIR "$N" HIR "蓦地大喝一声，单腿猛踢而出，直"
      #                     "踹$n" HIR "腰际，招式极为迅猛。\n" NOR", "HIR "突然只见$N" HIR "双腿连环踢出，挟着嚯嚯"
      #                     "风声，以千钧之势扫向$n" HIR "。\n" NOR", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 60,
      #                                      HIR "$n" HIR "连忙格挡，却只觉得力道大"
      #                                          "得出奇，登时被一脚踢得飞起。\n" NOR)"]}, "damage_formula": %{"formula": "ap / 3 + random(ap / 3)"}, "hit_formula": %{"left_side": "ap * 7 / 10 + random(ap)", "operator": "<", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}, {"neili", "-30"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-30"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(3);", "me->start_busy(3);", "me->start_busy(2);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3);
      #   - me->start_busy(3);
      #   - me->start_busy(2);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
