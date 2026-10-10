defmodule Kantele.Combat.Skills.Performs.JiuyinShengong.Zhua do
  @moduledoc """
  perform「九阴神爪」（source jiuyin-shengong/zhua.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "claw"}, {"ap", "unarmed"}, {"damage", "force"}, {"dp", "parry"}], "level_gates": [{"jiuyin-shengong", "280"}], "map_gates": [], "prepared_gates": [{"claw", "jiuyin-shengong"}, {"unarmed", "jiuyin-shengong"}], "resource_gates": [{"neili", "300"}], "var_gates": [{"damage", "0"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的九阴神功还不够娴熟，不能使用", "你现在内力太弱，不能使用", "你没有准备使用九阴神功，无法施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("claw")", "dp_formula": "target->query_skill("parry") +
      #            target->query_skill("martial-cognize", 1)"}, "color_codes": ["CYN", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "$N" HIY "微微一笑，右手成爪，忽的抓向$n" HIY "的要穴！\n" NOR", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 110, pmsg)", "= CYN "可是$p" CYN "看破了$P" CYN "的来势，应对得法，避开了这一抓。\n" NOR"], "success": ["= HIR "$N" HIR "这一爪来势好快，正抓中$n" HIR "的檀中大穴，$n" HIR
      #                          "一声惨叫，软绵绵的瘫了下去。\n" NOR", "HIR "$n连忙腾挪躲闪，然而“扑哧”一声，$N" HIR "五指正插入$n" HIR "的" + limb + "，$n" HIR "一声惨叫，血溅五步。\n" NOR"]}, "damage_formula": %{"formula": "0"}, "hit_formula": %{"left_side": "ap / 2 + random(ap * 2)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-180"}, {"neili", "-20"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-180"}, {"neili", "-20"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "target->start_busy(1 + random(3));", "me->start_busy(2);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - target->start_busy(1 + random(3));
      #   - me->start_busy(2);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // zhua.c 九阴神抓
      # 
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # inherit F_SSERVER;
      # 
      # #define ZHUA "「" HIR "九阴神爪" NOR "」"
      # 
      # int perform(object me, object target)
      # {
      #     int damage;
      #     string msg;
      #     string pmsg;
      #     string *limbs;
      #     string limb;
      #     int ap, dp;
      # 
      #     if (userp(me) && !me->query("can_perform/jiuyin-shengong/zhua"))
      #         return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #     if (!target)
      #         target = offensive_target(me);
      # 
      #     if (!target || !me->is_fighting(target))
      #         return notify_fail(ZHUA "只能对战斗中的对手使用。\n");
      # 
      #     if (me->query_temp("weapon"))
      #         return notify_fail(ZHUA "只能空手施展！\n");
      # 
      #     if ((int)me->query_skill("jiuyin-shengong", 1) < 280)
      #         return notify_fail("你的九阴神功还不够娴熟，不能使用" ZHUA "。\n");
      # 
      #     if ((int)me->query("neili", 1) < 300)
      #         return notify_fail("你现在内力太弱，不能使用" ZHUA "。\n");
      # 
      #     if (me->query_skill_prepared("claw") != "jiuyin-shengong" && me->query_skill_prepared("unarmed") != "jiuyin-shengong")
      #         return notify_fail("你没有准备使用九阴神功，无法施展" ZHUA "。\n");
      # 
      #     if (!living(target))
      #         return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #     msg = HIY "$N" HIY "微微一笑，右手成爪，忽的抓向$n" HIY "的要穴！\n" NOR;
      #     me->add("neili", -20);
      # 
      #     ap = me->query_skill("unarmed");
      #     if (ap < me->query_skill("claw"))
      #         ap = me->query_skill("claw");
      #     ap += me->query_skill("martial-cognize", 1);
      #     dp = target->query_skill("parry") +
      #          target->query_skill("martial-cognize", 1);
      # 
      #     me->want_kill(target);
      #     if (ap / 2 + random(ap * 2) > dp)
      #     {
      #         me->start_busy(2);
      #         me->add("neili", -180);
      #         damage = 0;
      # 
      #         if (me->query("max_neili") > target->query("max_neili") * 2)
      #         {
      #             msg += HIR "$N" HIR "这一爪来势好快，正抓中$n" HIR "的檀中大穴，$n" HIR
      #                        "一声惨叫，软绵绵的瘫了下去。\n" NOR;
      #             damage = -1;
      #         }
      #         else
      #         {
      #             target->start_busy(1 + random(3));
      # 
      #             damage = ap + (int)me->query_skill("force");
      #             //damage = damage / 2 + random(damage / 2);
      #             damage = damage / 2 + random(damage);
      # 
      #             if (arrayp(limbs = target->query("limbs")))
      #                 limb = limbs[random(sizeof(limbs))];
      #             else
      #                 limb = "要害";
      #             pmsg = HIR "$n连忙腾挪躲闪，然而“扑哧”一声，$N" HIR "五指正插入$n" HIR "的" + limb + "，$n" HIR "一声惨叫，血溅五步。\n" NOR;
      #             msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 110, pmsg);
      #         }
      #     }
      #     else
      #     {
      #         me->start_busy(2);
      #         msg += CYN "可是$p" CYN "看破了$P" CYN "的来势，应对得法，避开了这一抓。\n" NOR;
      #     }
      # 
      #     message_combatd(msg, me, target);
      #     if (damage < 0)
      #         target->die(me);
      # 
      #     return 1;
      # }
end
