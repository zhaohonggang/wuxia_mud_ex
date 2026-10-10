defmodule Kantele.Combat.Skills.Performs.YuenvJian.Xin do
  @moduledoc """
  perform「西子捧心」（source yuenv-jian/xin.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "sword"}, {"dp", "dodge"}], "level_gates": [{"dodge", "150"}, {"sword", "200"}, {"yuenv-jian", "150"}], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对。\n", "你的剑术修为不够，不能施展", "你的越女剑术的修为不够，不能施展", "你的轻功修为不够，不能施展", "你的真气不够！\n", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "(me->query_skill("sword") + me->query_skill("dodge")) / 2", "dp_formula": "target->query_skill("dodge")"}, "color_codes": ["HIC", "HIG", "HIM", "HIR", "HIY", "NOR"], "combat_exp_formulas": [{"lvl", "to_int(pow(to_float(me->query("combat_exp") * 10), 1.0 / 3))"}], "combat_messages": %{"fail": [], "other": ["HIG "\n$N" HIG "幽幽一声长叹，手中的" + weapon->name() +
      #                 HIG "就如闪电般刺向$n" HIG "的胸口。\n但见剑招轻盈灵动，优美华丽，就"
      #                 "连杀人间也不带一丝尘俗之气。\n" NOR", "= HIY "$n" HIY "只觉得$N" HIY "眼神中隐然透出"
      #                          "一股冰冷的寒意，心中不禁一颤。\n" NOR", "= HIC "$n" HIC "见状身形急退，避开了$N"
      #                          HIC "的无形剑气的凌厉一击！\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,
      #                                              HIR "$n" HIR "大吃一惊，慌忙躲避，然而剑"
      #                                              "气来的好快，哪里躲得开？\n只听$p" HIR
      #                                              "一声惨叫，胸口已经被剑气所伤！\n" NOR)", "= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 60,
      #                                                      HIC "$n重创之下不禁破绽迭出，$P"
      #                                                      HIC "见状随手刺出" + weapon->name() +
      #                                                      HIC "，又是一剑！\n" HIR "就听$p"
      #                                                      HIR "又是一声惨叫，痛苦不堪。\n" NOR)"]}, "damage_formula": %{"formula": "ap / 2 + random(ap / 2) + delta * 20"}, "hit_formula": %{"left_side": "ap * 7 / 10  + random(ap)", "operator": ">", "right_side": "dp"}, "misc_gates": ["gender"], "resource_adds": [{"neili", "-180"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-180"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(1);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
