defmodule Kantele.Combat.Skills.Performs.ZhongpingQiang.Ding do
  @moduledoc """
  perform「定岳七方」（source zhongping-qiang/ding.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "club"}, {"dp", "parry"}], "level_gates": [{"force", "180"}, {"zhongping-qiang", "120"}], "map_gates": [{"club", "zhongping-qiang"}], "prepared_gates": [], "resource_gates": [{"max_neili", "2000"}, {"neili", "200"}], "var_gates": [{"i", "7"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你所使用的武器不对，难以施展", "你中平枪法不够娴熟，难以施展", "你没有激发中平枪法，难以施展", "你的内功火候不够，难以施展", "你的内力修为不够，难以施展", "你现在的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("club")", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["HIC", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["= HIC "$n" HIC "见$N" HIC "攻势凶猛异常，实非"
      #                          "寻常，急忙打起精神，小心应付开来。\n" NOR"], "success": ["HIY "$N" HIY "身形一转，施出中平枪法绝技「" HIR "定岳七方"
      #                 HIY "」，手中" + weapon->name() + HIY "接连七刺，枪枪不离"
      #                "$n" HIY "要害！\n" NOR", "= HIR "$n" HIR "见$N" HIR "攻势凶猛异常，实非"
      #                          "寻常，不由心生寒意，招架登时散乱。\n" NOR"]}, "hit_formula": %{"left_side": "ap / 2 + random(ap * 2)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-7 * 20"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "club"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(1 + random(7));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1 + random(7));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
