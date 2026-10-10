defmodule Kantele.Combat.Skills.Performs.QujingGunfa.Zhen do
  @moduledoc """
  perform「震雷乾坤」（source qujing-gunfa/zhen.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "club"}, {"dp", "parry"}], "level_gates": [{"force", "350"}, {"qujing-gunfa", "200"}], "map_gates": [{"club", "qujing-gunfa"}, {"force", "hunyuan-yiqi"}, {"force", "luohan-fumogong"}, {"force", "yijinjing"}], "prepared_gates": [], "resource_gates": [{"max_neili", "4000"}, {"max_neili", "4500"}, {"neili", "300"}], "var_gates": [{"i", "10"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你现在没有激发少林内功为内功，难以施展", "你没有激发取经棍法，难以施展", "你取经棍法不够娴熟，难以施展", "你的内功修为不够，难以施展", "你的内力修为太弱，难以施展", "你现在的真气太弱，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("club")", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["HIC", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["= HIC "$n" HIC "见$N" HIC "气势如虹，心下凛然，急"
      #                          "忙凝神聚气，小心应付！\n" NOR"], "success": ["HIW "$N" HIW "将手中" + weapon->name() + HIW "缓缓压向$n"
      #                 HIW "，棍体隐隐带着风雷之劲，正是取经棍法杀着「" HIR "震"
      #                 "雷乾坤" HIW "」！\n电光火石间，棍端竟全被紫电所笼罩，" +
      #                 weapon->name() + HIW "幻作千百根相似，奔雷掣电般向$n" HIW
      #                 "席卷而去。\n" NOR", "= HIR "$n" HIR "被$N" HIR "气势所撼，完全不知该如"
      #                          "何招架，竟而呆立当场！\n" NOR"]}, "hit_formula": %{"left_side": "ap / 2 + random(ap * 2)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-200"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "club"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-200"}], "affect_by": [], "apply_adds": ["attack", "damage"], "busy_lines": ["me->start_busy(1 + random(9));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1 + random(9));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define ZHEN "「" HIR "震雷乾坤" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         object weapon;
      #         string msg;
      #         int i, ap, dp, count;
      # 
      #         if (userp(me) && ! me->query("can_perform/qujing-gunfa/zhen"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(ZHEN "只能对战斗中的对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon")) ||
      #             (string)weapon->query("skill_type") != "club")
      #                 return notify_fail("你使用的武器不对，难以施展" ZHEN "。\n");
      #                 
      #         if ((me->query_skill_mapped("force") != "hunyuan-yiqi") && (me->query_skill_mapped("force") != "yijinjing") && (me->query_skill_mapped("force") != "luohan-fumogong")) 
      #                 return notify_fail("你现在没有激发少林内功为内功，难以施展" ZHEN "。\n"); 
      # 
      #         if (me->query_skill_mapped("club") != "qujing-gunfa")
      #                 return notify_fail("你没有激发取经棍法，难以施展" ZHEN "。\n");
      # 
      #         if(me->query_skill("qujing-gunfa", 1) < 200 )
      #                 return notify_fail("你取经棍法不够娴熟，难以施展" ZHEN "。\n");
      # 
      #         if( (int)me->query_skill("force") < 350 )
      #                 return notify_fail("你的内功修为不够，难以施展" ZHEN "。\n");
      # 
      #         //if( (int)me->query("max_neili") < 4500 )
      #         if( (int)me->query("max_neili") < 4000 )
      #                 return notify_fail("你的内力修为太弱，难以施展" ZHEN "。\n");
      # 
      #         if( (int)me->query("neili") < 300 )
      #                 return notify_fail("你现在的真气太弱，难以施展" ZHEN "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIW "$N" HIW "将手中" + weapon->name() + HIW "缓缓压向$n"
      #               HIW "，棍体隐隐带着风雷之劲，正是取经棍法杀着「" HIR "震"
      #               "雷乾坤" HIW "」！\n电光火石间，棍端竟全被紫电所笼罩，" +
      #               weapon->name() + HIW "幻作千百根相似，奔雷掣电般向$n" HIW
      #               "席卷而去。\n" NOR;
      # 
      #         ap = me->query_skill("club");
      #         dp = target->query_skill("parry");
      # 
      #         if (ap / 2 + random(ap * 2) > dp)
      #         {
      #                 msg += HIR "$n" HIR "被$N" HIR "气势所撼，完全不知该如"
      #                        "何招架，竟而呆立当场！\n" NOR;
      #                 count = ap / 5;
      #                 me->add_temp("apply/attack", count);
      #                 me->add_temp("apply/damage", count);
      #         } else
      #         {
      #                 msg += HIC "$n" HIC "见$N" HIC "气势如虹，心下凛然，急"
      #                        "忙凝神聚气，小心应付！\n" NOR;
      #                 count = 0;
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         me->add("neili", -200);
      # 
      #         for (i = 0; i < 10; i++)
      #         {
      #                 if (! me->is_fighting(target))
      #                         break;
      #                 COMBAT_D->do_attack(me, target, weapon, 0);
      #         }
      # 
      #         me->add_temp("apply/attack", -count);
      #         me->add_temp("apply/damage", -count);
      #         me->start_busy(1 + random(9));
      #         return 1;
      # }
end
