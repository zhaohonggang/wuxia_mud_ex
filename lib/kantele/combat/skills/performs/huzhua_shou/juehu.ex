defmodule Kantele.Combat.Skills.Performs.HuzhuaShou.Juehu do
  @moduledoc """
  perform「绝户神抓」（source huzhua-shou/juehu.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"damage", "huzhua-shou"}], "level_gates": [{"huzhua-shou", "120"}], "map_gates": [{"claw", "huzhua-shou"}], "prepared_gates": [{"claw", "huzhua-shou"}], "resource_gates": [{"neili", "300"}, {"shen", "10000"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你必须空手才能使用", "你的虎爪绝户手不够娴熟，难以施展", "你没有激发虎爪绝户手，难以施展", "你没有准备使用虎爪绝户手，无法使用", "你现在真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["CYN", "HIC", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["= CYN "可是$p" CYN "看破了$N"
      #                          CYN "的企图，躲开了这招杀着。\n" NOR"], "success": ["HIR "$N" HIR "大喝一声，变掌为爪，双爪化出漫天爪影，如狂风骤雨一般向$n"
      #                 HIR "的要害抓去！\n" NOR", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 40,
      #                                              HIR "结果$p" HIR "一声惨嚎，没能招架住$P"
      #                                              HIR "凌厉的攻势，被抓得皮肉分离，鲜血飞溅！\n" NOR)"]}, "damage_formula": %{"formula": "me->query_skill("huzhua-shou", 1)"}, "resource_adds": [{"neili", "-100"}, {"neili", "-200"}, {"shen", "-3000"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-200"}, {"shen", "-3000"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
