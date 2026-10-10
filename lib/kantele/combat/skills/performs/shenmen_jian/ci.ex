defmodule Kantele.Combat.Skills.Performs.ShenmenJian.Ci do
  @moduledoc """
  perform「神门刺」（source shenmen-jian/ci.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "sword"}, {"dp", "parry"}, {"skill", "shenmen-jian"}], "level_gates": [], "map_gates": [{"sword", "shenmen-jian"}], "prepared_gates": [], "resource_gates": [{"neili", "200"}], "var_gates": [{"dp", "1"}, {"skill", "120"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你的神门十三剑等级不够，难以施展", "对方没有使用兵器，难以施展", "你现在没有激发神门十三剑，难以施展", "你现在真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("sword")", "dp_formula": "1"}, "color_codes": ["CYN", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["= CYN "可是$n" CYN "看破了$N" CYN "的企图，将手中兵刃挥"
      #                          "舞得密不透风，挡开了$N" CYN "的兵器。\n"NOR"], "success": ["HIR "突然$N" HIR "一声冷哼，手中" + weapon->name() + HIR
      #                 "中攻直进，直刺$n" HIR "拿着的" + weapon2->name() + HIR
      #                 "的手腕。\n" NOR", "= HIR "$n" HIR "只觉手腕一阵刺痛，手中" + weapon2->name() +
      #                          HIR "再也拿捏不住，脱手而飞。\n" NOR"]}, "hit_formula": %{"left_side": "ap / 3 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-120"}, {"neili", "-40"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-120"}, {"neili", "-40"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2 + random(2));", "target->start_busy(2);", "me->start_busy(3);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2 + random(2));
      #   - target->start_busy(2);
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
