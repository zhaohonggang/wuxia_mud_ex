defmodule Kantele.Combat.Skills.Performs.TiangangChenfa.Bai do
  @moduledoc """
  perform「朝拜天罡」（source tiangang-chenfa/bai.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "whip"}, {"dp", "parry"}], "level_gates": [{"tiangang-chenfa", "120"}], "map_gates": [{"whip", "tiangang-chenfa"}], "prepared_gates": [], "resource_gates": [{"max_neili", "1500"}, {"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你天罡尘法不够娴熟，难以施展", "你的内力修为不足，难以施展", "你现在真气不够，难以施展", "你没有激发天罡尘法，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("whip")", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["CYN", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "但见$N" HIY "手中" + weapon->query("name") + HIY "窜动不"
      #                 "已，接连变幻了数种招式，分袭$n" HIY "各处要害。\n"", "= CYN "可是$p" CYN "看破了$P"
      #                          CYN "招中虚实，当即纵身而起，躲避开来。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,
      #                                              HIR "$n" HIR "急忙躲闪，却发现$N" HIR
      #                                              "的" + weapon->name() + HIR "已然拂中"
      #                                              "胸前要穴，顿感气血上涌，难受之极。\n" NOR)"]}, "damage_formula": %{"formula": "ap * 4 / 3"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-180"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "whip"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-180"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
