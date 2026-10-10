defmodule Kantele.Combat.Skills.Performs.HuashanZhang.Piao do
  @moduledoc """
  perform「飞絮飘渺」（source huashan-zhang/piao.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [], "level_gates": [{"huashan-zhang", "30"}], "map_gates": [], "prepared_gates": [{"strike", "huashan-zhang"}], "resource_gates": [{"neili", "60"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的华山掌法不够娴熟，不会使用", "你没有准备使用华山掌法，无法施展", "你现在真气不够，无法施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["CYN", "HIG", "HIM", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["HIM "\n猛然间$N" HIM "双掌不断拍向$n" HIM "出，风声呼呼，攻到途中忽又左"
      #                 "手虚出右手作势欲发，虚虚实实，飘渺不定，正是华山绝招「" HIG  "飞絮飘渺" HIM
      #                 "」。 顷刻剑$n" HIM "已被$N" HIM "掌风笼罩。\n" NOR", "= CYN "可是$n" CYN "看破其中虚实，更不理会。\n" NOR"], "success": ["= HIR "结果$p" HIR "一时无法辨别其中虚实，竟无法施招。\n" NOR"]}, "resource_adds": [{"neili", "-30"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-30"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (target->is_busy())", "target->start_busy((int)me->query_skill("strike") / 25 + 2);", "me->start_busy(1);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (target->is_busy())
      #   - target->start_busy((int)me->query_skill("strike") / 25 + 2);
      #   - me->start_busy(1);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
