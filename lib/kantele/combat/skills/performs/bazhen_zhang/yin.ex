defmodule Kantele.Combat.Skills.Performs.BazhenZhang.Yin do
  @moduledoc """
  perform「神卦天印」（source bazhen-zhang/yin.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"damage", "strike"}], "level_gates": [{"bazhen-zhang", "130"}, {"force", "180"}], "map_gates": [{"strike", "bazhen-zhang"}], "prepared_gates": [{"strike", "bazhen-zhang"}], "resource_gates": [{"neili", "300"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的内功修为不够，难以施展", "你的八阵八卦掌不够娴熟，难以施展", "你没有激发八阵八卦掌，难以施展", "你没有准备八阵八卦掌，难以施展", "你现在真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["CYN", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["= CYN "可是$p" CYN "奋力招架，不露半点破绽，将$P"
      #                          CYN "这一招驱之于无形。\n" NOR"], "success": ["HIR "$N" HIR "凝神沉履，积聚全身功力于一掌，携着雷霆之势奋力向$n"
      #                 HIR "胸前拍落。\n" NOR", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 45,
      #                                              HIR "结果$p" HIR "招架不及，被$P" HIR
      #                                              "一掌印在胸口，接连断了数根肋骨，喷出"
      #                                              "一大口鲜血！\n" NOR)"]}, "damage_formula": %{"formula": "me->query_skill("strike")"}, "resource_adds": [{"neili", "-100"}, {"neili", "-250"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-250"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
