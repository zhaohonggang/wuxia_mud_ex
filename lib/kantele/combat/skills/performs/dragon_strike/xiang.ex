defmodule Kantele.Combat.Skills.Performs.DragonStrike.Xiang do
  @moduledoc """
  perform「xiang」（source dragon-strike/xiang.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "strike"}, {"dp", "parry"}], "level_gates": [{"dragon-strike", "150"}, {"force", "300"}], "map_gates": [], "prepared_gates": [{"strike", "dragon-strike"}], "resource_gates": [{"max_neili", "2000"}, {"neili", "500"}, {"qi", "800"}], "var_gates": [{"i", "6"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["「龙翔九天」只能在战斗中对对手使用。\n", "「龙翔九天」只能空手使用。\n", "你的内力修为还不够，无法施展「龙翔九天」。\n", "你的真气不够！\n", "你的体力现在不够！\n", "你的降龙十八掌火候不够，无法使用「龙翔九天」！\n", "你的内功修为不够，无法使用「龙翔九天」！\n", "你现在没有准备使用降龙十八掌，无法使用「龙翔九天」！\n", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("strike") + me->query("str") * 10", "dp_formula": "target->query_skill("parry") + target->query("dex") * 6"}, "color_codes": ["HIC", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "$N" HIY "深吸一口气，跨前一步，双掌猛然翻滚，"
      #                 "缤纷而出，宛如一条神龙攀蜒于九天之上！\n\n" NOR", "= HIC "$n" HIC "凝神应战，竭尽所能化解$P" HIC
      #                          "这几掌。\n" NOR"], "success": ["= HIR "$n" HIR "面对$P" HIR "这排山倒海攻势，完全"
      #                          "无法抵挡，唯有退后。\n" NOR"]}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-300"}, {"qi", "-100"}], "resource_queries": ["max_neili", "neili", "qi"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-300"}, {"qi", "-100"}], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["if (random(5) < 2 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(5));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (random(5) < 2 && ! target->is_busy())
      #   - target->start_busy(1);
      #   - me->start_busy(1 + random(5));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
