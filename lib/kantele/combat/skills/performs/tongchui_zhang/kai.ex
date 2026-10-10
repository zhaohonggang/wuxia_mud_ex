defmodule Kantele.Combat.Skills.Performs.TongchuiZhang.Kai do
  @moduledoc """
  perform「五丁开山」（source tongchui-zhang/kai.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"damage", "strike"}], "level_gates": [{"force", "90"}, {"tongchui-zhang", "80"}], "map_gates": [{"strike", "tongchui-zhang"}], "prepared_gates": [{"strike", "tongchui-zhang"}], "resource_gates": [{"neili", "100"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你铜锤掌法不够娴熟，难以施展", "你没有激发铜锤掌法，难以施展", "你没有准备铜锤掌法，难以施展", "你的内功修为不够，难以施展", "你现在的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["CYN", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["= CYN "可是$n" CYN "毫不慌张，当即向后轻"
      #                          "轻一跃，闪避开来。\n" NOR"], "success": ["HIY "$N" HIY "右掌暗聚力道，十指分张，蓦地一招「"
      #                 HIR "五丁开山" HIY "」向$n" HIY "背心拍去。\n" NOR", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 20,
      #                                              HIR "结果$n" HIR "闪避不及，顿被$N" HIR
      #                                              "这掌击个正中，五脏六腑翻腾不已。\n" NOR)"]}, "damage_formula": %{"formula": "me->query_skill("strike")"}, "resource_adds": [{"neili", "-30"}, {"neili", "-80"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-30"}, {"neili", "-80"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
