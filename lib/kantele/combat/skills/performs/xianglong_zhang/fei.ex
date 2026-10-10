defmodule Kantele.Combat.Skills.Performs.XianglongZhang.Fei do
  @moduledoc """
  perform「飞龙在天」（source xianglong-zhang/fei.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "strike"}, {"dp", "parry"}], "level_gates": [{"force", "300"}, {"xianglong-zhang", "150"}], "map_gates": [{"strike", "xianglong-zhang"}], "prepared_gates": [{"strike", "xianglong-zhang"}], "resource_gates": [{"max_neili", "3000"}, {"neili", "500"}], "var_gates": [{"i", "6"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你降龙十八掌火候不够，难以施展", "你没有激发降龙十八掌，难以施展", "你没有准备降龙十八掌，难以施展", "你的内功修为不够，难以施展", "你的内力修为不够，难以施展", "你现在的真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("strike") + me->query("str") * 10", "dp_formula": "target->query_skill("parry") + target->query("dex") * 10"}, "color_codes": ["HIC", "HIR", "HIW", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "$N" HIY "施出降龙十八掌「" HIW "飞龙在天"
      #                 HIY "」，双掌翻滚，宛如一条神龙攀蜒于九天之上"
      #                 "。\n" NOR", "= HIC "$n" HIC "心底微微一惊，心知不妙，急忙"
      #                          "凝聚心神，竭尽所能化解$N" HIC "数道掌力。\n" NOR"], "success": ["= HIR "$n" HIR "面对$N" HIR "这排山倒海般的攻"
      #                          "势，完全无法抵挡，招架散乱，连连退后。\n" NOR"]}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-300"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-300"}], "affect_by": [], "apply_adds": ["attack", "unarmed_damage"], "busy_lines": ["if (random(5) < 2 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(6));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (random(5) < 2 && ! target->is_busy())
      #   - target->start_busy(1);
      #   - me->start_busy(1 + random(6));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
