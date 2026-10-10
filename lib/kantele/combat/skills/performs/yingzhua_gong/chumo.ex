defmodule Kantele.Combat.Skills.Performs.YingzhuaGong.Chumo do
  @moduledoc """
  perform「chumo」（source yingzhua-gong/chumo.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "force"}, {"dp", "parry"}, {"skill", "yingzhua-gong"}], "level_gates": [], "map_gates": [{"claw", "yingzhua-gong"}], "prepared_gates": [], "resource_gates": [{"neili", "250"}], "var_gates": [{"skill", "135"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["「荡妖除魔」只能在战斗中对对手使用。\n", "你的鹰爪功等级不够，不会使用「荡妖除魔」！\n", "你的真气不够，无法运用「荡妖除魔」！\n", "你没有激发鹰爪功，无法使用「荡妖除魔」！\n", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("force") + me->query_skill("claw")", "dp_formula": "target->query_skill("parry") + target->query_skill("dodge")"}, "color_codes": ["CYN", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "$N" HIY "微微一笑，双掌缓缓的向$n" HIY "抓出，此招"
      #             "看上去也平平无奇，并无多少精妙变化！\n" NOR", "= CYN "可是$p" CYN "没有轻视$P" CYN
      #                          "这一抓，连忙招架，顺势跃开，没有被$P"
      #                          CYN "得手。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 45,
      #                                              HIR "不知怎么的，$p" HIR "却偏偏躲不开$P"
      #                                              HIR "这一抓，结果被抓了个正中，不由得闷"
      #                                              "哼一声，退了几步。\n" NOR)"]}, "damage_formula": %{"formula": "ap / 2 + random(ap / 4)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-200"}, {"neili", "-40"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-200"}, {"neili", "-40"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
