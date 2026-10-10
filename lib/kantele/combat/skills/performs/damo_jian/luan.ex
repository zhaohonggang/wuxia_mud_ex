defmodule Kantele.Combat.Skills.Performs.DamoJian.Luan do
  @moduledoc """
  perform「达摩乱气剑」（source damo-jian/luan.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "sword"}, {"dp", "force"}, {"lvl", "damo-jian"}], "level_gates": [{"damo-jian", "200"}], "map_gates": [{"sword", "damo-jian"}], "prepared_gates": [], "resource_gates": [{"max_neili", "2000"}, {"neili", "300"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"affect_by_callbacks": [%{"buff_name": "damo_luanqi", "duration_formula": "5 + random(lvl / 20)", "id_formula": "me->query("id")", "level_formula": "lvl + random(lvl)"}], "all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你所使用的武器不对，难以施展", "你达摩剑法不够娴熟，难以施展", "你没有激发达摩剑法，难以施展", "你的内力修为不够，难以施展", "你现在的真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("sword") + me->query_skill("force")", "dp_formula": "target->query_skill("force") * 2"}, "callback_functions": [%{"body": "int lvl = me->query_skill("damo-jian", 1);
      #   
      #           target->affect_by("damo_luanqi",
      #                   ([ "level"    : lvl + random(lvl),
      #                      "id"       : me->query("id"),
      #                  ", "name": "final", "params": "object me, object target, int damage", "return_type": "string"}], "color_codes": ["CYN", "HIM", "HIR", "NOR"], "combat_messages": %{"fail": ["= CYN "可是$n" CYN "内力深厚，使得$P"
      #                          CYN "这一招没有起到任何作用。\n" NOR"], "other": ["HIM "$N" HIM "回转剑锋，手中" + weapon->name() +
      #                 HIM "紫光荡漾，如作龙吟，无形剑气笼罩$n"
      #                 HIM "全身。\n" NOR", "= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 70,
      #                                              (: final, me, target, damage :))"], "success": []}, "damage_formula": %{"formula": "ap / 3 + random(ap / 3)"}, "do_damage_calls": [%{"attack_type": "WEAPON_ATTACK", "callback": "final", "damage_factor": 70, "damage_var": "damage"}], "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}, {"neili", "-200"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-200"}], "affect_by": ["damo_luanqi"], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(4);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(4);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
