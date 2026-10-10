defmodule Kantele.Combat.Skills.Performs.QiankunJian.Ni do
  @moduledoc """
  perform「逆转乾坤」（source qiankun-jian/ni.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "sword"}, {"dp", "dodge"}], "level_gates": [{"force", "300"}, {"qiankun-jian", "180"}], "map_gates": [{"sword", "qiankun-jian"}], "prepared_gates": [], "resource_gates": [{"neili", "400"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你的内功的修为不够，难以施展", "你的乾坤神剑修为不够，难以施展", "你的真气不够，难以施展", "你没有激发乾坤神剑，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("sword") + me->query_skill("force")", "dp_formula": "target->query_skill("dodge") + target->query_skill("parry")"}, "color_codes": ["CYN", "HIR", "HIW", "NOR"], "combat_exp_formulas": [{"lvl", "to_int(pow(to_float(me->query("combat_exp") * 10), 1.0 / 3))"}], "combat_messages": %{"fail": [], "other": ["HIW "$N" HIW "一声清啸，手中" + weapon->name() +
      #                 HIW "一振，将乾坤剑法逆行施展，顿时剑影重重，万"
      #                 "道光华直追$n" + HIW "而去！\n" NOR", "= CYN "可是$n" CYN "看破" CYN "$N" CYN
      #                          "的招数，飞身一跃，闪开了这神鬼莫测"
      #                          "的一击。\n"NOR"], "success": ["= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 120,
      #                                              HIR "$n" HIR "完全无法看清招中虚实，微"
      #                                              "微一楞间，发现" + weapon->name() + HIR
      #                                              "竟已没入自己胸口数寸。\n" NOR)"]}, "damage_formula": %{"formula": "ap / 3 + random(ap / 3)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-200"}, {"neili", "-80"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-200"}, {"neili", "-80"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(4);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(4);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
