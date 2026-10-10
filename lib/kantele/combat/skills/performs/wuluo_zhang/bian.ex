defmodule Kantele.Combat.Skills.Performs.WuluoZhang.Bian do
  @moduledoc """
  perform「风云变幻」（source wuluo-zhang/bian.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"lvl", "wuluo-zhang"}], "level_gates": [{"wuluo-zhang", "100"}], "map_gates": [{"strike", "wuluo-zhang"}], "prepared_gates": [{"strike", "wuluo-zhang"}], "resource_gates": [{"neili", "100"}], "var_gates": [{"i", "5"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你五罗轻烟掌不够娴熟，难以施展", "你没有激发五罗轻烟掌，难以施展", "你没有准备五罗轻烟掌，难以施展", "你现在真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIC", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["HIC "$N" HIC "施出五罗轻烟掌绝技，单掌轻轻一抖，登时化出五道掌"
      #                 "影，轻飘飘向$n" HIC "拍去。\n" NOR", "= HIC "可是$n" HIC "凝神顿气，奋力抵挡，丝"
      #                          "毫不受掌影的干扰，。\n" NOR"], "success": ["= HIR "$n" HIR "顿时觉得眼花缭乱，全然分辨"
      #                          "不清真伪，只得拼命运动抵挡。\n" NOR"]}, "resource_adds": [{"neili", "-50"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-50"}], "affect_by": [], "apply_adds": ["attack", "unarmed_damage"], "busy_lines": ["me->start_busy(1 + random(5));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1 + random(5));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define BIAN "「" HIC "风云变幻" NOR "」"
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
      #         if (userp(me) && ! me->query("can_perform/wuluo-zhang/bian"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(BIAN "只能对战斗中的对手使用。\n");
      # 
      #         if (objectp(me->query_temp("weapon")))
      #                 return notify_fail(BIAN "只能空手施展。\n");
      # 
      #         if ((lvl = (int)me->query_skill("wuluo-zhang", 1)) < 100)
      #                 return notify_fail("你五罗轻烟掌不够娴熟，难以施展" BIAN "。\n");
      # 
      #         if (me->query_skill_mapped("strike") != "wuluo-zhang")
      #                 return notify_fail("你没有激发五罗轻烟掌，难以施展" BIAN "。\n");
      # 
      #         if (me->query_skill_prepared("strike") != "wuluo-zhang")
      #                 return notify_fail("你没有准备五罗轻烟掌，难以施展" BIAN "。\n");
      # 
      #         if ((int)me->query("neili") < 100)
      #                 return notify_fail("你现在真气不足，难以施展" BIAN "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIC "$N" HIC "施出五罗轻烟掌绝技，单掌轻轻一抖，登时化出五道掌"
      #               "影，轻飘飘向$n" HIC "拍去。\n" NOR;
      #         me->add("neili", -50);
      # 
      #         if (random(me->query_skill("force") + me->query_skill("strike")) >
      #             target->query_skill("force"))
      #         {
      #                 msg += HIR "$n" HIR "顿时觉得眼花缭乱，全然分辨"
      #                        "不清真伪，只得拼命运动抵挡。\n" NOR;
      #                 count = lvl / 10;
      #                 me->add_temp("apply/attack", count);
      #                 me->add_temp("apply/unarmed_damage", count / 2);
      #         } else
      #         {
      #                 msg += HIC "可是$n" HIC "凝神顿气，奋力抵挡，丝"
      #                        "毫不受掌影的干扰，。\n" NOR;
      #                 count = 0;
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         for (i = 0; i < 5; i++)
      #         {
      #                 if (! me->is_fighting(target))
      #                         break;
      #                 COMBAT_D->do_attack(me, target, 0, 0);
      #         }
      #         me->start_busy(1 + random(5));
      #         me->add_temp("apply/attack", -count);
      #         me->add_temp("apply/unarmed_damage", -count / 2);
      #         return 1;
      # }
end
