defmodule Kantele.Combat.Skills.Performs.QuanzhenJian.Hua do
  @moduledoc """
  perform「一气化三清」（source quanzhen-jian/hua.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "xiantian-gong"}, {"count", "xiantian-gong"}, {"dp", "force"}], "level_gates": [{"quanzhen-jian", "200"}, {"xiantian-gong", "100"}], "map_gates": [{"force", "xiantian-gong"}, {"sword", "quanzhen-jian"}], "prepared_gates": [], "resource_gates": [{"max_neili", "4500"}, {"neili", "500"}], "var_gates": [{"i", "3"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你所使用的武器不对，难以施展", "你全真剑法不够娴熟，难以施展", "你的先天功不够娴熟，难以施展", "你没有激发全真剑法，难以施展", "你没有激发先天功，难以施展", "你的内力修为不够，难以施展", "你现在的真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("xiantian-gong", 1) + me->query_skill("sword")", "dp_formula": "target->query_skill("force") + target->query_skill("parry", 1) * 2 / 3"}, "color_codes": ["CYN", "HIM", "HIR", "HIW", "HIY", "NOR"], "combat_exp_formulas": [{"lvl", "to_int(pow(to_float(me->query("combat_exp") * 10), 1.0 / 3))"}], "combat_messages": %{"fail": [], "other": ["HIW "$N" HIW "一声长吟，将内力全然运到剑上，" + weapon->name() +
      #                 HIW "剑脊顿时" HIM "紫芒" HIW "闪耀，化作数道剑气劲逼$n"
      #                 HIW "。\n" NOR", "= CYN "可是$n" CYN "看破了$N" CYN "的企图，斜跃避开。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 100,
      #                                              HIR "顿时只听$n" HIR "一声惨叫，剑气及"
      #                                              "身，身上接连射出数道血柱。\n" NOR)"]}, "damage_formula": %{"formula": "ap / 2 + random(ap)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-200"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-200"}], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["me->start_busy(3);", "me->start_busy(2);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3);
      #   - me->start_busy(2);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
