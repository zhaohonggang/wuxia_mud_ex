defmodule Kantele.Combat.Skills.Performs.RuanhongZhusuo.Suo do
  @moduledoc """
  perform「锁龙诀」（source ruanhong-zhusuo/suo.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "whip"}, {"dp", "parry"}], "level_gates": [{"ruanhong-zhusuo", "150"}], "map_gates": [{"whip", "ruanhong-zhusuo"}], "prepared_gates": [], "resource_gates": [{"neili", "350"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，无法施展", "你的软红蛛索不够娴熟，无法施展", "你的真气不够，无法施展", "你没有激发软红蛛索，无法施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("whip")", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["HIC", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "$N" HIW "使出「锁龙」诀，手中" + weapon->name() +
      #                 HIW "一抖，登时幻出漫天鞭影，宛如蛟龙通天，一齐袭向$n"
      #                 HIW "而去！\n\n" NOR", "= HIC "结果$p" HIC "被$P" HIC
      #                          "攻了个措手不及，目接不暇，疲于奔命！\n" NOR", "= HIC "$n" HIC "见$N" HIC "鞭势恢弘，心下凛然，凝神应付。\n" NOR"], "success": []}, "hit_formula": %{"left_side": "ap / 2 + random(ap * 2)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-attack_time * 20"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "whip"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["me->start_busy(1 + random(attack_time));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1 + random(attack_time));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
