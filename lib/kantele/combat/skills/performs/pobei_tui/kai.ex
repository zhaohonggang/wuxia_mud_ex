defmodule Kantele.Combat.Skills.Performs.PobeiTui.Kai do
  @moduledoc """
  perform「五岳为开」（source pobei-tui/kai.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"lvl", "pobei-tui"}], "level_gates": [{"force", "150"}, {"pobei-tui", "100"}], "map_gates": [{"unarmed", "pobei-tui"}], "prepared_gates": [{"unarmed", "pobei-tui"}], "resource_gates": [{"neili", "150"}], "var_gates": [{"i", "4"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你必须空手才能使用", "你的内功火候太浅，难以施展", "你的破碑腿不够娴熟，难以施展", "你现在没有激发破碑腿，难以施展", "你现在没有准备破碑腿，难以施展", "你现在真气太弱，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIC", "HIR", "NOR", "WHT"], "combat_messages": %{"fail": [], "other": ["WHT "只见$N" WHT "身形猛转，霎那间双腿流星般连环踢出，足带风尘，腿影将$n"
      #                 WHT "团团笼罩。\n" NOR", "= HIC "可是$n" HIC "凝神顿气，奋力抵挡，丝毫不"
      #                          "受腿影的干扰，。\n" NOR"], "success": ["= HIR "$n" HIR "见无数腿影向自己袭来，全然分辨"
      #                          "不清真伪，只得拼命运动抵挡。\n" NOR"]}, "resource_adds": [{"neili", "-100"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["me->start_busy(random(4));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(random(4));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define KAI "「" WHT "五岳为开" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         string msg;
      #         int count;
      #         int lvl;
      #         int i;
      # 
      #         if (userp(me) && ! me->query("can_perform/pobei-tui/kai"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(KAI "只能对战斗中的对手使用。\n");
      # 
      #         if (objectp(me->query_temp("weapon")))
      #                 return notify_fail("你必须空手才能使用" KAI "。\n");
      # 
      #         if ((int)me->query_skill("force") < 150)
      #                 return notify_fail("你的内功火候太浅，难以施展" KAI "。\n");
      # 
      #         if ((lvl = (int)me->query_skill("pobei-tui", 1)) < 100)
      #                 return notify_fail("你的破碑腿不够娴熟，难以施展" KAI "。\n");
      # 
      #         if (me->query_skill_mapped("unarmed") != "pobei-tui")
      #                 return notify_fail("你现在没有激发破碑腿，难以施展" KAI "。\n");
      # 
      #         if (me->query_skill_prepared("unarmed") != "pobei-tui")
      #                 return notify_fail("你现在没有准备破碑腿，难以施展" KAI "。\n");
      # 
      #         if ((int)me->query("neili", 1) < 150)
      #                 return notify_fail("你现在真气太弱，难以施展" KAI "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = WHT "只见$N" WHT "身形猛转，霎那间双腿流星般连环踢出，足带风尘，腿影将$n"
      #               WHT "团团笼罩。\n" NOR;
      #         me->add("neili", -100);
      # 
      #         if (random(me->query_skill("force") + me->query_skill("unarmed")) >
      #             target->query_skill("force"))
      #         {
      #                 msg += HIR "$n" HIR "见无数腿影向自己袭来，全然分辨"
      #                        "不清真伪，只得拼命运动抵挡。\n" NOR;
      #                 count = lvl / 5;
      #                 me->add_temp("apply/attack", count);
      #         } else
      #         {
      #                 msg += HIC "可是$n" HIC "凝神顿气，奋力抵挡，丝毫不"
      #                        "受腿影的干扰，。\n" NOR;
      #                 count = 0;
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         for (i = 0; i < 4; i++)
      #         {
      #                 if (! me->is_fighting(target))
      #                         break;
      #                 COMBAT_D->do_attack(me, target, 0, 0);
      #         }
      #         me->start_busy(random(4));
      #         me->add_temp("apply/attack", -count);
      #         return 1;
      # }
end
