defmodule Kantele.Combat.Skills.Performs.BaguaBiao.Xian do
  @moduledoc """
  perform「镖中现掌」（source bagua-biao/xian.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "strike"}, {"dp", "dodge"}], "level_gates": [{"bagua-biao", "120"}, {"bagua-zhang", "120"}, {"force", "150"}], "map_gates": [{"strike", "bagua-zhang"}, {"throwing", "bagua-biao"}], "prepared_gates": [{"strike", "bagua-zhang"}], "resource_gates": [{"neili", "150"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你现在手中并没有拿着暗器。\n", "你没有激发八卦掌，难以施展", "你没有准备八卦掌，难以施展", "你没有激发八卦镖诀，难以施展", "你的八卦掌不够娴熟，难以施展", "你的八卦镖诀不够娴熟，难以施展", "你的内功火候不够，难以施展", "你现在真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "amount_calls": [{"query_amount", ""}], "ap_dp_formulas": %{"ap_formula": "me->query_skill("strike", 1) +
      #                me->query_skill("throwing")", "dp_formula": "target->query_skill("dodge", 1) +
      #                target->query_skill("parry", 1)"}, "color_codes": ["HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "突然只听$N" HIY "喝道：“$n" HIY "看招！”"
      #                 "说完单手一扬，袖底顿时窜出一道金光，直射$n" HIY
      #                 "而去！\n" NOR", "= HIY "可是$p" HIY "看破了$P" HIY "的企图，没"
      #                          "有受到迷惑，招手将暗器全部揽了下来。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 30,
      #                                              HIY "可只见$n" HIY "哈哈一笑，身子一矮"
      #                                              "，躲了过去。\n" NOR + HIR "哪知方才的"
      #                                              "暗器竟是虚招，等$p" HIR "反应时$N" HIR
      #                                              "已至跟前，双掌齐施，重重的印在$n" HIR
      #                                              "胸前。\n" NOR)"]}, "damage_formula": %{"formula": "ap / 3 + random(ap / 2)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "throwing"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
