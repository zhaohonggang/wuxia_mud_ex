defmodule Kantele.Combat.Skills.Performs.HuaguMianzhang.Hua do
  @moduledoc """
  perform「hua」（source huagu-mianzhang/hua.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "huagu-mianzhang"}, {"dp", "force"}, {"lvl", "huagu-mianzhang"}], "level_gates": [{"force", "150"}, {"huagu-mianzhang", "100"}], "map_gates": [{"strike", "huagu-mianzhang"}], "prepared_gates": [], "resource_gates": [{"neili", "300"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"affect_by_callbacks": [%{"buff_name": "huagu", "duration_formula": "lvl / 60 + random(lvl / 60)", "id_formula": "me->query("id")", "level_formula": "me->query("jiali") + random(me->query("jiali"))"}], "all_fail_messages": ["辣手化骨只能对战斗中的对手使用。\n", "你的内功火候不够，无法施展化骨掌。\n", "你的化骨绵掌还不够娴熟，不会化骨掌。\n", "你的真气不够，不能化骨。\n", "你没有激发化骨绵掌，无法施展化骨掌。\n", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("huagu-mianzhang", 1) / 2 * 3", "dp_formula": "target->query_skill("force")"}, "callback_functions": [%{"body": "int lvl = me->query_skill("huagu-mianzhang", 1) / 2 * 3;
      #   
      #           target->affect_by("huagu",
      #                   ([ "level"    : me->query("jiali") + random(me->query("jiali")),
      #                      "id"   ", "name": "final", "params": "object me, object target, int damage", "return_type": "string"}], "color_codes": ["CYN", "HIR", "MAG", "NOR"], "combat_messages": %{"fail": [], "other": ["MAG "$N" MAG "掌出如风，轻轻拍向$n" MAG "的肩头。\n"NOR", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 40,
      #                                             (: final, me, target, damage :))", "= CYN "可是$p" CYN "急忙闪在一旁，躲了开去。\n" NOR"], "success": []}, "damage_formula": %{"formula": "ap / 3 + random(ap / 2)"}, "do_damage_calls": [%{"attack_type": "UNARMED_ATTACK", "callback": "final", "damage_factor": 40, "damage_var": "damage"}], "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}], "affect_by": ["huagu"], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
