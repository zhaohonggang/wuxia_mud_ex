defmodule Kantele.Combat.Skills.Performs.PiaofengQuan.Juan do
  @moduledoc """
  perform「卷字决」（source piaofeng-quan/juan.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [], "level_gates": [{"piaofeng-quan", "30"}], "map_gates": [], "prepared_gates": [{"cuff", "piaofeng-quan"}], "resource_gates": [{"neili", "80"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的飘风拳法不够娴熟，不会使用", "你没有准备使用飘风拳法，无法施展", "你现在真气不够，无法施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["CYN", "HIC", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIC "\n只见$N" HIC "右拳直出，中途猛地一转，突然发力，身法"
      #                 "陡快，将$n" HIC "笼罩， 正是飘风拳法绝招「" HIW "卷字决" HIC "」。\n" NOR", "= CYN "可是$p" CYN "奋力一架，硬生生格开了$P"
      #                          CYN "这一拳。\n" NOR"], "success": ["= HIR "结果$p" HIR "运力招架，一时却觉得"
      #                          "内力不济，被$P" HIR "抢住手腕一拉，顿时立足"
      #                          "不稳，滴溜溜打了两个圈子。\n" NOR"]}, "resource_adds": [{"neili", "-40"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-40"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (target->is_busy())", "target->start_busy((int)me->query_skill("cuff") / 22);", "me->start_busy(1);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (target->is_busy())
      #   - target->start_busy((int)me->query_skill("cuff") / 22);
      #   - me->start_busy(1);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # 
      # #define JUAN "「" HIW "卷字决" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      # //    object weapon;
      #     string msg;
      # 
      #     if (! target) target = offensive_target(me);
      # 
      #         if (userp(me) && ! me->query("can_perform/piaofeng-quan/juan"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #     if (! target || ! me->is_fighting(target))
      #         return notify_fail(JUAN "只能对战斗中的对手使用。\n");
      # 
      #     if (target->is_busy())
      #         return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧！\n");
      # 
      #     if ((int)me->query_skill("piaofeng-quan", 1) < 30)
      #         return notify_fail("你的飘风拳法不够娴熟，不会使用" JUAN "。\n");
      # 
      #         if (me->query_skill_prepared("cuff") != "piaofeng-quan")
      #                 return notify_fail("你没有准备使用飘风拳法，无法施展" JUAN "。\n");
      # 
      #         if (me->query("neili") < 80)
      #                 return notify_fail("你现在真气不够，无法施展" JUAN "。\n");
      # 
      #         if (! living(target))
      #                return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIC "\n只见$N" HIC "右拳直出，中途猛地一转，突然发力，身法"
      #               "陡快，将$n" HIC "笼罩， 正是飘风拳法绝招「" HIW "卷字决" HIC "」。\n" NOR;
      # 
      #         me->add("neili", -40);
      #     if (random(me->query_skill("cuff")) > (int)target->query_skill("force") / 2)
      #         {
      #         msg += HIR "结果$p" HIR "运力招架，一时却觉得"
      #                        "内力不济，被$P" HIR "抢住手腕一拉，顿时立足"
      #                        "不稳，滴溜溜打了两个圈子。\n" NOR;
      #         target->start_busy((int)me->query_skill("cuff") / 22);
      #     } else
      #         {
      #         msg += CYN "可是$p" CYN "奋力一架，硬生生格开了$P"
      #                        CYN "这一拳。\n" NOR;
      #         me->start_busy(1);
      #     }
      #     message_sort(msg, me, target);
      # 
      #     return 1;
      # }
end
