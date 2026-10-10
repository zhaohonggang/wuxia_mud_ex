defmodule Kantele.Combat.Skills.Performs.Shenzhaojing.Wu do
  @moduledoc """
  perform「无影拳舞」（source shenzhaojing/wu.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "force"}, {"dp", "dodge"}], "level_gates": [{"shenzhaojing", "200"}, {"unarmed", "200"}], "map_gates": [{"unarmed", "shenzhaojing"}], "prepared_gates": [{"unarmed", "shenzhaojing"}], "resource_gates": [{"max_neili", "5000"}, {"neili", "500"}], "var_gates": [{"i", "6"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你必须空手才能施展", "你没有激发神照经神功为拳脚，无法施展", "你现在没有准备使用神照经神功，无法施展", "你的神照经神功火候不够，无法施展", "你的基本拳脚火候不够，无法施展", "你的内力修为不足，无法施展", "你的真气不够，无法施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("force") + me->query("con") * 10", "dp_formula": "target->query_skill("dodge") + target->query("dex") * 10"}, "color_codes": ["HIC", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["= HIC "$n" HIC "微一凝神，面对$N" HIC "这排"
      #                          "山倒海的攻势却丝毫不乱，小心招架。\n" NOR"], "success": ["HIR "$N" HIR "一声暴喝，将神照功功力聚之于拳，携着雷霆万"
      #                 "钧之势向$n"HIR"连环攻出。\n"NOR", "= HIR "$n" HIR "面对$N" HIR "这排山倒海的攻"
      #                          "势，不禁心生惧意，慌乱中破绽迭出。\n" NOR"]}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-200"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-200"}], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["if (random(3) == 0 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(5));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (random(3) == 0 && ! target->is_busy())
      #   - target->start_busy(1);
      #   - me->start_busy(1 + random(5));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
