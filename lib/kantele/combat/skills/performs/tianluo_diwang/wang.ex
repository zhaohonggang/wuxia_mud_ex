defmodule Kantele.Combat.Skills.Performs.TianluoDiwang.Wang do
  @moduledoc """
  perform「天罗地网」（source tianluo-diwang/wang.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"level", "tianluo-diwang"}], "level_gates": [{"dodge", "40"}, {"tianluo-diwang", "60"}], "map_gates": [], "prepared_gates": [{"strike", "tianluo-diwang"}], "resource_gates": [{"neili", "70"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你必须空手才能施展", "你的天罗地网掌还不够娴熟，无法施展", "你的轻功修为不够，无法施展", "你没有准备天罗地网掌，难以施展", "你现在真气不够，无法使用", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["CYN", "HIG", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIG "\n$N" HIG "双掌齐出，幻化出无数掌影，将$n" HIG "团团笼罩。" NOR", "CYN "可是$p" CYN "身形一闪，跃出$P" CYN "的掌力"
      #                         "所及的范围。\n" NOR"], "success": ["HIR "结果$p" HIR "被$P" HIR "压制的难以反击，"
      #                         "只能竭力抵挡！\n" NOR"]}, "resource_adds": [{"neili", "-60"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-60"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (target->is_busy())", "target->start_busy(level / 16 + 2);", "me->start_busy(2 + random(2));", "me->start_busy(1);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (target->is_busy())
      #   - target->start_busy(level / 16 + 2);
      #   - me->start_busy(2 + random(2));
      #   - me->start_busy(1);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
