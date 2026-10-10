defmodule Kantele.Combat.Skills.Performs.XiaoyaoJian.Qi do
  @moduledoc """
  perform「奇剑诀」（source xiaoyao-jian/qi.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "sword"}, {"dp", "parry"}], "level_gates": [{"force", "160"}, {"xiaoyao-jian", "160"}], "map_gates": [{"sword", "xiaoyao-jian"}], "prepared_gates": [], "resource_gates": [{"max_neili", "2200"}, {"neili", "350"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你所使用的武器不对，难以施展", "你逍遥剑法不够娴熟，难以施展", "你没有激发逍遥剑法，难以施展", "你的内功火候不够，难以施展", "你内力修为不足，难以施展", "你现在的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("sword") + me->query_skill("dodge")", "dp_formula": "target->query_skill("parry") + target->query_skill("dodge")"}, "color_codes": ["CYN", "HIG", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "\n$N" HIW "将" + wn + HIW "斜指长空，猛地飞身跃起，"
      #                 + wn + HIW "忽左忽右，飘忽不定，猛然间破空长响，" + wn + HIW
      #                 "直指向$n" HIW "咽喉。这正是逍遥剑法之「" HIG "奇剑诀" HIW "」，"
      #                 "当真是招招精奇，神妙无比。\n" NOR", "CYN "然而$n" CYN "眼明手快，侧身一跳"
      #                         "躲过$N" CYN "这一剑。\n" NOR"], "success": ["COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 78,
      #                                             HIR "$n" HIR "只见一道电光从半空袭来，"
      #                                             "心中惊骇不已，但鲜血已从$n胸口喷出。\n"
      #                                             NOR)"]}, "damage_formula": %{"formula": "ap + random(ap / 4)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-200"}, {"neili", "-300"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-200"}, {"neili", "-300"}], "affect_by": [], "apply_adds": [], "busy_lines": ["//me->start_busy(2 + random(4));", "me->start_busy(2);", "//me->start_busy(2);", "me->start_busy(2 + random(4));"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - //me->start_busy(2 + random(4));
      #   - me->start_busy(2);
      #   - //me->start_busy(2);
      #   - me->start_busy(2 + random(4));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
