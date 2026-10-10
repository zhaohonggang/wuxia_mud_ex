defmodule Kantele.Combat.Skills.Performs.XuangongQuan.Xuan do
  @moduledoc """
  perform「玄功无极劲」（source xuangong-quan/xuan.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"damage", "xuangong-quan"}, {"skill", "xuangong-quan"}], "level_gates": [], "map_gates": [{"unarmed", "xuangong-quan"}], "prepared_gates": [{"unarmed", "xuangong-quan"}], "resource_gates": [{"neili", "200"}], "var_gates": [{"skill", "120"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的无极玄功拳等级不够，难以施展", "你的真气不够，难以施展", "你没有激发无极玄功拳，难以施展", "你现在没有准备使用无极玄功拳，无法使用", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["CYN", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "只见$N" HIW "双手回圈，慢慢的引动气流，正当$n"
      #                 HIW "吃惊间，$P" HIW "双拳已陡然破空贯出。\n" NOR", "= CYN "可是$p" CYN "看破了$P"
      #                          CYN "的企图，并没有上当。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 60,
      #                                              HIR "$n" HIR "急忙抽身躲避，可已然不及，被$N"
      #                                              HIR "双拳捶个正中。\n:内伤@?")"]}, "damage_formula": %{"formula": "(int)me->query_skill("xuangong-quan", 1)"}, "resource_adds": [{"neili", "-100"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(3);", "target->start_busy(random(3));", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3);
      #   - target->start_busy(random(3));
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
