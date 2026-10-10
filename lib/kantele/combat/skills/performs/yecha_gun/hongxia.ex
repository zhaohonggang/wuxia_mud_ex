defmodule Kantele.Combat.Skills.Performs.YechaGun.Hongxia do
  @moduledoc """
  perform「红霞贯日」（source yecha-gun/hongxia.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "club"}, {"dp", "parry"}, {"skill", "yecha-gun"}], "level_gates": [], "map_gates": [{"club", "yecha-gun"}], "prepared_gates": [], "resource_gates": [{"neili", "200"}], "var_gates": [{"skill", "120"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的夜叉棍法等级不够，难以施展", "你的真气不够，难以施展", "你没有激发夜叉棍法，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("club")", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["CYN", "HIR", "NOR"], "combat_messages": %{"fail": ["= CYN "$n" CYN "只见$N" CYN "看破了棍法中的虚实，凝神" 
      #                          "化解开来。\n" NOR"], "other": [], "success": ["HIR "$N" HIR "身形曼妙，手中铁棍" HIR "虚虚实实，舞出无数的棍影" 
      #                 "宛若满天的红霞，将$n重重包围。\n" NOR", "= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 30, 
      #                                              HIR "$n" HIR "只觉$N" HIR "棍影重重，" 
      #                                              "无所不在，自己无处躲闪，顿时身上" 
      #                                              "连中数棍，被攻了个措手不及。\n" NOR)"]}, "damage_formula": %{"formula": "ap / 6 + random(ap / 6)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap * 4 / 3)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-150"}, {"neili", "-50"}, {"neili", "-80"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-150"}, {"neili", "-50"}, {"neili", "-80"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (target->is_busy())", "me->start_busy(1);", "if (ap / 2 + random(ap) > dp && ! target->is_busy())", "target->start_busy(ap / 30 + 2);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - if (target->is_busy())
      #   - me->start_busy(1);
      #   - if (ap / 2 + random(ap) > dp && ! target->is_busy())
      #   - target->start_busy(ap / 30 + 2);
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
