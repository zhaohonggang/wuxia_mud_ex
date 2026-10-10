defmodule Kantele.Combat.Skills.Performs.ZhongnanZhi.Zhi do
  @moduledoc """
  perform「剑指南山」（source zhongnan-zhi/zhi.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"damage", "finger"}], "level_gates": [{"force", "80"}, {"zhongnan-zhi", "60"}], "map_gates": [{"finger", "zhongnan-zhi"}], "prepared_gates": [{"finger", "zhongnan-zhi"}], "resource_gates": [{"neili", "60"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你终南指法不够娴熟，难以施展", "你没有激发终南指法，难以施展", "你没有准备终南指法，难以施展", "你内功修为不够，难以施展", "你现在的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["CYN", "HIG", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["HIG "$N" HIG "斜斜一指刺出，指尖晃动不已，遥遥点向$n"
      #                 HIG "要穴所在。\n" NOR", "= CYN "可是$p" CYN "识破了$P"
      #                          CYN "这一招，斜斜一跃避开。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 20,
      #                                              HIR "结果$p" HIR "招架失误，被$P" HIR
      #                                              "这一指点了个正着，内息登时一滞，气血倒流。\n" NOR)"]}, "damage_formula": %{"formula": "me->query_skill("finger")"}, "resource_adds": [{"neili", "-20"}, {"neili", "-60"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-20"}, {"neili", "-60"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
