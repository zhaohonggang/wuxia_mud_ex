defmodule Kantele.Combat.Skills.Performs.TaixuanGong.Xuan do
  @moduledoc """
  perform「太玄激劲」（source taixuan-gong/xuan.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "taixuan-gong"}, {"dp", "dodge"}, {"lvl", "taixuan-gong"}], "level_gates": [{"force", "300"}, {"taixuan-gong", "240"}], "map_gates": [{"blade", "taixuan-gong"}, {"sword", "taixuan-gong"}, {"unarmed", "taixuan-gong"}], "prepared_gates": [], "resource_gates": [{"max_neili", "5000"}, {"neili", "800"}], "var_gates": [{"i", "15"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的真气不够，无法施展", "你的内力修为还不足以使出", "你的内功火候不够，难以施展", "你的太玄功还不够熟练，无法使用", "你还没有学会如何利用太玄功驾御兵器，这招只能空手施展！\n", "你没有准备太玄功，无法使用", "你没有准备太玄功，无法使用", "你使用的武器不对，无法施展", "你还没有激发太玄功，无法施展", "你还没有激发太玄功，无法施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("taixuan-gong", 1)", "dp_formula": "target->query_skill("dodge", 1)"}, "color_codes": ["HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "\n霎时间$N" HIW "只觉思绪狂涌，当即闭上双眼，再不理睬$n"
      #                 HIW "如何招架，只管施招攻出！此时侠客岛石壁上的千百种招"
      #                 "式，转眼已从$N" HIW "心底传向手足，尽数向$n" HIW "袭去！\n" NOR"], "success": []}, "hit_formula": %{"left_side": "ap / 3 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-600"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_forbidden": ["blade", "sword"], "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-600"}], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["if (random(2) == 1 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(5));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (random(2) == 1 && ! target->is_busy())
      #   - target->start_busy(1);
      #   - me->start_busy(1 + random(5));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
