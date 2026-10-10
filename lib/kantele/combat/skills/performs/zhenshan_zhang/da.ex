defmodule Kantele.Combat.Skills.Performs.ZhenshanZhang.Da do
  @moduledoc """
  perform「隔山打牛」（source zhenshan-zhang/da.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"damage", "force"}], "level_gates": [{"zhenshan-zhang", "40"}], "map_gates": [{"strike", "zhenshan-zhang"}], "prepared_gates": [{"strike", "zhenshan-zhang"}], "resource_gates": [{"max_neili", "200"}, {"neili", "50"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你必须空手才能使用", "你的震山掌不够娴熟，难以施展", "你的内功修为不足，难以施展", "你没有激发震山掌，难以施展", "你没有准备使用震山掌，难以施展", "你现在真气太弱，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["CYN", "HIR", "NOR", "WHT"], "combat_messages": %{"fail": [], "other": ["WHT "$N" WHT "脚蹲马步，深吸一口气，使出隔山打牛，双掌对准$n"
      #                 WHT "平平推出。\n" NOR", "= CYN "可是$p" CYN "看破了$P"
      #                          CYN "的企图，并没有上当。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 30,
      #                                              HIR "$n" HIR "见势连忙向后一纵，但却只觉"
      #                                              "胸口一震，顿时两耳轰鸣，已被$N" HIR "掌"
      #                                              "劲所伤！\n:内伤@?")"]}, "damage_formula": %{"formula": "(int)me->query_skill("force", 1)"}, "resource_adds": [{"neili", "-30"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-30"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(3);", "target->start_busy(random(3));", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3);
      #   - target->start_busy(random(3));
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
