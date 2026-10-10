defmodule Kantele.Combat.Skills.Performs.BaihuaCuoquan.Yi do
  @moduledoc """
  perform「百花错易」（source baihua-cuoquan/yi.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "unarmed"}, {"dp", "parry"}], "level_gates": [{"baihua-cuoquan", "150"}, {"force", "280"}], "map_gates": [], "prepared_gates": [{"unarmed", "baihua-cuoquan"}], "resource_gates": [{"max_neili", "3000"}, {"neili", "500"}], "var_gates": [{"i", "6"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的内力的修为不够，现在无法使用", "你的内功火候不足，无法使用", "你的百花错拳火候不够，无法使用", "你现在没有准备使用百花错拳，无法使用", "你的真气不够，无法运用", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("unarmed") + me->query("str") * 10", "dp_formula": "target->query_skill("parry") + target->query("dex") * 10"}, "color_codes": ["HIR", "HIW", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "$N" HIW "大喝一声，双掌纷飞，擒拿手中夹着鹰爪功，左手查"
      #                 "拳，右手绵掌。攻出去是\n八卦掌，收回时已是太极拳，诸家杂陈，"
      #                 "毫无规律，铺天盖地向$n" HIW "狂涌而去。\n\n" NOR", "= HIY "$n" HIY "只见$N" HIY "运拳如奔，快拳缤纷递出，"
      #                          "连忙振作精神勉强抵挡。\n" NOR"], "success": ["= HIR "$n" HIR "只见$N" HIR "运拳如奔，快拳缤纷递出，"
      #                          "顿感头晕目眩，不知该如何抵挡。\n" NOR"]}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-300"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-300"}], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["if (random(5) < 2 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(6));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (random(5) < 2 && ! target->is_busy())
      #   - target->start_busy(1);
      #   - me->start_busy(1 + random(6));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // yi.c 百花错易
      # 
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define YI "「" HIW "百花错易" NOR "」"
      # 
      # inherit F_SSERVER;
      #  
      # int perform(object me, object target)
      # {
      #         string msg;
      #         int ap, dp;
      #         int count;
      #         int i;
      #  
      #         if (! target)
      #         {
      #                 me->clean_up_enemy();
      #                 target = me->select_opponent();
      #         }
      # 
      #         if (userp(me) && ! me->query("can_perform/baihua-cuoquan/yi"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(YI "只能对战斗中的对手使用。\n");
      #  
      #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
      #                 return notify_fail(YI "只能空手施展。\n");
      #                 
      #         if (me->query("max_neili") < 3000)
      #                 return notify_fail("你的内力的修为不够，现在无法使用" YI "。\n");
      # 
      #         if ((int)me->query_skill("force") < 280)
      #                 return notify_fail("你的内功火候不足，无法使用" YI "。\n");
      # 
      #         if ((int)me->query_skill("baihua-cuoquan", 1) < 150)
      #                 return notify_fail("你的百花错拳火候不够，无法使用" YI "。\n");
      # 
      #         if (me->query_skill_prepared("unarmed") != "baihua-cuoquan")
      #                 return notify_fail("你现在没有准备使用百花错拳，无法使用" YI "。\n");
      # 
      #         if ((int)me->query("neili") < 500)
      #                 return notify_fail("你的真气不够，无法运用" YI "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIW "$N" HIW "大喝一声，双掌纷飞，擒拿手中夹着鹰爪功，左手查"
      #               "拳，右手绵掌。攻出去是\n八卦掌，收回时已是太极拳，诸家杂陈，"
      #               "毫无规律，铺天盖地向$n" HIW "狂涌而去。\n\n" NOR;
      # 
      #         ap = me->query_skill("unarmed") + me->query("str") * 10;
      #         dp = target->query_skill("parry") + target->query("dex") * 10;
      # 
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 count = ap / 12;
      #                 msg += HIR "$n" HIR "只见$N" HIR "运拳如奔，快拳缤纷递出，"
      #                        "顿感头晕目眩，不知该如何抵挡。\n" NOR;
      #         } else
      #         {
      #                 msg += HIY "$n" HIY "只见$N" HIY "运拳如奔，快拳缤纷递出，"
      #                        "连忙振作精神勉强抵挡。\n" NOR;
      #                 count = 0;
      #         }
      # 
      #         message_vision(msg, me, target);
      #         me->add_temp("apply/attack", count);
      # 
      #         me->add("neili", -300);
      # 
      #         for (i = 0; i < 6; i++)
      #         {
      #                 if (! me->is_fighting(target))
      #                         break;
      #                 if (random(5) < 2 && ! target->is_busy())
      #                         target->start_busy(1);
      # 
      #                 COMBAT_D->do_attack(me, target, 0, 0);
      #         }
      # 
      #         me->start_busy(1 + random(6));
      #         me->add_temp("apply/attack", -count);
      # 
      #         return 1;
      # }
end
