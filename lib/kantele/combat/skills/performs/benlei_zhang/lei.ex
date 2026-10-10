defmodule Kantele.Combat.Skills.Performs.BenleiZhang.Lei do
  @moduledoc """
  perform「雷霆万钧」（source benlei-zhang/lei.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"damage", "benlei-zhang"}], "level_gates": [{"benlei-zhang", "120"}], "map_gates": [{"strike", "benlei-zhang"}], "prepared_gates": [{"strike", "benlei-zhang"}], "resource_gates": [{"neili", "400"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的霹雳奔雷掌还不够娴熟，难以施展", "你没有激发霹雳奔雷掌，难以施展", "你没有准备霹雳奔雷掌，难以施展", "你现在真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["CYN", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "只见$N" HIY "聚力于掌，平平推出，顿时掌风澎湃，掌力"
      #                 "携着雷霆万钧之势猛贯向$n" HIY "而去！\n" NOR", "= CYN "可是$p" CYN "看破了$N" CYN
      #                          "的企图，躲开了这招杀着。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 25,
      #                                              HIR "结果只听$n" HIR "一声闷哼，$N"
      #                                              HIR "掌劲穿胸而过，“哇”的喷出一大"
      #                                              "口鲜血。\n" NOR)"]}, "damage_formula": %{"formula": "me->query_skill("benlei-zhang", 1)"}, "resource_adds": [{"neili", "-200"}, {"neili", "-300"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-200"}, {"neili", "-300"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(3);", "me->start_busy(2);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3);
      #   - me->start_busy(2);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
