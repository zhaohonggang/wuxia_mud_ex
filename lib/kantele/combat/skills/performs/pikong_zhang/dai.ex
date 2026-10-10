defmodule Kantele.Combat.Skills.Performs.PikongZhang.Dai do
  @moduledoc """
  perform「披星戴月」（source pikong-zhang/dai.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"damage", "strike"}], "level_gates": [{"force", "120"}, {"pikong-zhang", "80"}], "map_gates": [{"strike", "pikong-zhang"}], "prepared_gates": [{"strike", "pikong-zhang"}], "resource_gates": [{"neili", "100"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你劈空掌不够娴熟，难以施展", "你的内功修为不够，难以施展", "你现在的真气不够，难以施展", "你没有激发劈空掌，难以施展", "你没有准备劈空掌，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["CYN", "HIB", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["HIB "只见$N" HIB "双掌交叠，云贯而出，舞出无数圈劲气，一环环"
      #                 "向$n" HIB "斫去。\n" NOR", "= CYN "可是$p" CYN "识破了$P"
      #                          CYN "这一招，斜斜一跃避开。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 20,
      #                                              HIR "$n" HIR "一惊，被$N" HIR "掌劲击"
      #                                              "在胸前，经脉受震，登时呕出一口鲜血！\n" NOR)"]}, "damage_formula": %{"formula": "me->query_skill("strike")"}, "resource_adds": [{"neili", "-30"}, {"neili", "-50"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-30"}, {"neili", "-50"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
