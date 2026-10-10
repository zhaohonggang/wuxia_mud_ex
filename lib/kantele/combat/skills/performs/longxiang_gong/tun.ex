defmodule Kantele.Combat.Skills.Performs.LongxiangGong.Tun do
  @moduledoc """
  perform「龙吞势」（source longxiang-gong/tun.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "unarmed"}, {"dp", "parry"}, {"foc", "force"}], "level_gates": [{"longxiang-gong", "180"}], "map_gates": [{"force", "longxiang-gong"}, {"unarmed", "longxiang-gong"}], "prepared_gates": [{"unarmed", "longxiang-gong"}], "resource_gates": [{"max_neili", "3000"}, {"neili", "500"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的龙象般若功修为不够，难以施展", "你的内力修为不足，难以施展", "你没有激发龙象般若功为拳脚，难以施展", "你没有激发龙象般若功为内功，难以施展", "你没有准备使用龙象般若功，难以施展", "你现在的真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("unarmed") +
      #                me->query_skill("force")", "dp_formula": "target->query_skill("parry") +
      #                target->query_skill("force")"}, "buff_delete": ["long_tun"], "call_outs": [%{"args": "me", "delay": "50", "fn": "remove_effect"}], "callback_functions": [%{"body": "if (me->query_temp("long_tun"))
      #           {
      #                   me->delete_temp("long_tun");
      #                   tell_object(me, "你经过调气养息，又可以继续施展" TUN "了。\n");", "name": "remove_effect", "params": "object me", "return_type": "void"}], "color_codes": ["CYN", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["= CYN "可是$n" CYN "见$N" CYN "此招来势非凡，急"
      #                          "忙向后横移数尺，终于躲避开来。\n" NOR"], "success": ["HIY "$N" HIY "双臂左右分张，形若龙嘴，所施正是龙象般若功绝学「"
      #                 HIR "龙吞势" HIY "」。霎时呼\n啸声大作，但见一股澎湃无比的罡劲"
      #                 "至$N" HIY "双掌间涌出，云贯向$n" HIY "而去。\n" NOR", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 80,
      #                                                  HIR "$n" HIR "一声哀嚎，被$N" HIR "的罡"
      #                                                  "气划中气门，真气在体内四处乱窜，惨不堪"
      #                                                  "言。\n" NOR)"]}, "damage_formula": %{"formula": "ap / 2 + random(ap) + random(foc)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-200"}, {"neili", "-300"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-200"}, {"neili", "-300"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(3);", "me->start_busy(4);"], "remote_damage": true, "set_flags": [], "temp_set": ["long_tun"]}
      #   - me->start_busy(3);
      #   - me->start_busy(4);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define TUN "「" HIR "龙吞势" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # inherit F_CLEAN_UP;
      # 
      # void remove_effect(object me);
      # 
      # int perform(object me, object target)
      # {
      # //      object weapon;
      #         int ap, dp, foc, damage;
      #         string msg;
      # 
      #         if (userp(me) && ! me->query("can_perform/longxiang-gong/tun"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(TUN "只能对战斗中的对手使用。\n");
      # 
      #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
      #                 return notify_fail(TUN "只能空手施展。\n");
      # 
      #         if (me->query_temp("long_tun"))
      #                 return notify_fail(TUN "无法连续施展。\n");
      # 
      #         if ((int)me->query_skill("longxiang-gong", 1) < 180)
      #                 return notify_fail("你的龙象般若功修为不够，难以施展" TUN "。\n");
      # 
      #         if (me->query("max_neili") < 3000)
      #                 return notify_fail("你的内力修为不足，难以施展" TUN "。\n");
      # 
      #         if (me->query_skill_mapped("unarmed") != "longxiang-gong")
      #                 return notify_fail("你没有激发龙象般若功为拳脚，难以施展" TUN "。\n");
      # 
      #         if (me->query_skill_mapped("force") != "longxiang-gong")
      #                 return notify_fail("你没有激发龙象般若功为内功，难以施展" TUN "。\n");
      # 
      #         if (me->query_skill_prepared("unarmed") != "longxiang-gong")
      #                 return notify_fail("你没有准备使用龙象般若功，难以施展" TUN "。\n");
      # 
      #         if (me->query("neili") < 500)
      #                 return notify_fail("你现在的真气不足，难以施展" TUN "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIY "$N" HIY "双臂左右分张，形若龙嘴，所施正是龙象般若功绝学「"
      #               HIR "龙吞势" HIY "」。霎时呼\n啸声大作，但见一股澎湃无比的罡劲"
      #               "至$N" HIY "双掌间涌出，云贯向$n" HIY "而去。\n" NOR;
      # 
      #         me->set_temp("long_tun", 1);
      #         me->start_call_out((: call_other, __FILE__, "remove_effect", me :), 50);
      # 
      #         ap = me->query_skill("unarmed") +
      #              me->query_skill("force");
      # 
      #         dp = target->query_skill("parry") +
      #              target->query_skill("force");
      # 
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 foc = target->query_skill("force");
      #                 damage = ap / 2 + random(ap) + random(foc);
      # 
      #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 80,
      #                                                HIR "$n" HIR "一声哀嚎，被$N" HIR "的罡"
      #                                                "气划中气门，真气在体内四处乱窜，惨不堪"
      #                                                "言。\n" NOR);
      # 
      #                 me->start_busy(3);
      #                 me->add("neili", -300);
      #         } else
      #         {
      #                 me->start_busy(4);
      #                 me->add("neili", -200);
      #                 msg += CYN "可是$n" CYN "见$N" CYN "此招来势非凡，急"
      #                        "忙向后横移数尺，终于躲避开来。\n" NOR;
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
      # 
      # void remove_effect(object me)
      # {
      #         if (me->query_temp("long_tun"))
      #         {
      #                 me->delete_temp("long_tun");
      #                 tell_object(me, "你经过调气养息，又可以继续施展" TUN "了。\n");
      #         }
      # }
end
