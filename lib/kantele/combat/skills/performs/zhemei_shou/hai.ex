defmodule Kantele.Combat.Skills.Performs.ZhemeiShou.Hai do
  @moduledoc """
  perform「海渊式」（source zhemei-shou/hai.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "hand"}, {"damage", "zhemei-shou"}, {"dp", "dodge"}], "level_gates": [{"force", "200"}, {"zhemei-shou", "130"}], "map_gates": [{"hand", "zhemei-shou"}], "prepared_gates": [{"hand", "zhemei-shou"}], "resource_gates": [{"neili", "300"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的内功火候不够，难以施展", "你的逍遥折梅手等级不够，难以施展", "你没有激发逍遥折梅手，难以施展", "你没有准备使用逍遥折梅手，难以施展", "你现在真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("hand")", "dp_formula": "target->query_skill("dodge")"}, "color_codes": ["HIB", "HIC", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["HIB "$N" HIB "挥手疾舞，施出逍遥折梅手「海渊式」，手法"
      #                 "缥缈，虚虚实实罩向$n" HIB "要害。\n" NOR", "= HIC "可是$p" HIC "身手敏捷，身形急转，巧妙的躲过了$P"
      #                          HIC "的攻击。\n"NOR"], "success": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 65,
      #                                      HIR "霎时漫天掌影化为一抓，$p" HIR "闪"
      #                                              "避不及，被$N" HIR "五指插入胸膛，鲜血"
      #                                              "四处飞溅！\n" NOR)"]}, "damage_formula": %{"formula": "me->query_skill("zhemei-shou", 1)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}, {"neili", "-50"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-50"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(3);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3);
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
