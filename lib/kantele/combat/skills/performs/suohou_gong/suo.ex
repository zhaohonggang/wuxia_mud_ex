defmodule Kantele.Combat.Skills.Performs.SuohouGong.Suo do
  @moduledoc """
  perform「铁爪锁喉」（source suohou-gong/suo.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "claw"}, {"damage", "force"}, {"dp", "dodge"}], "level_gates": [{"suohou-gong", "150"}], "map_gates": [{"claw", "suohou-gong"}], "prepared_gates": [{"claw", "suohou-gong"}], "resource_gates": [{"neili", "200"}], "var_gates": [{"damage", "0"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你琐喉功火候不够，难以施展", "你没有激发琐喉功，难以施展", "你没有准备琐喉功，难以施展", "你现在的真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("claw")", "dp_formula": "target->query_skill("dodge")"}, "color_codes": ["CYN", "HIR", "NOR", "RED"], "combat_messages": %{"fail": [], "other": ["= CYN "可是$n" CYN "看破了$P"
      #                          CYN "的企图，身形急动，躲开了这一抓。\n"NOR"], "success": ["HIR "$N" HIR "一声冷笑，蓦地拔地而起，右手一招「" NOR +
      #                 CYN "铁爪锁喉" HIR "」直取$n" HIR "颈部。\n" NOR", "= HIR "霎时只听「喀嚓」一声脆响，$N" HIR "五"
      #                                  "指竟将$n" HIR "的喉结捏个粉碎。\n" NOR "("
      #                                  " $n" RED "受伤过重，已经有如风中残烛，随时"
      #                                  "都可能断气。" NOR ")\n"", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 75,
      #                                                      HIR "$n" HIR "慌忙躲闪，却听「喀嚓」一"
      #                                                      "声，$N" HIR "五指正拿中$n" HIR "的" +
      #                                                      limb + "。\n" NOR)"]}, "damage_formula": %{"formula": "0"}, "hit_formula": %{"left_side": "ap / 2 + random(ap * 2 / 3)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}, {"neili", "-180"}, {"neili", "-20"}, {"neili", "-50"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-180"}, {"neili", "-20"}, {"neili", "-50"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(1);", "target->start_busy(1 + random(3));", "me->start_busy(3);", "me->start_busy(4);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1);
      #   - target->start_busy(1 + random(3));
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
      # #define SUO "「" CYN "铁爪锁喉" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         int ap, dp, damage;
      #         string msg;
      #         string *limbs, limb;
      # 
      #         if (userp(me) && ! me->query("can_perform/suohou-gong/suo"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target)
      #         {
      #                 me->clean_up_enemy();
      #                 target = me->select_opponent();
      #         }
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(SUO "只能对战斗中的对手使用。\n");
      # 
      #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
      #                 return notify_fail(SUO "只能空手施展。\n");
      # 
      #         if ((int)me->query_skill("suohou-gong", 1) < 150)
      #                 return notify_fail("你琐喉功火候不够，难以施展" SUO "。\n");
      # 
      #         if (me->query_skill_mapped("claw") != "suohou-gong")
      #                 return notify_fail("你没有激发琐喉功，难以施展" SUO "。\n");
      # 
      #         if (me->query_skill_prepared("claw") != "suohou-gong")
      #                 return notify_fail("你没有准备琐喉功，难以施展" SUO "。\n");
      # 
      #         if ((int)me->query("neili", 1) < 200)
      #                 return notify_fail("你现在的真气不足，难以施展" SUO "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIR "$N" HIR "一声冷笑，蓦地拔地而起，右手一招「" NOR +
      #               CYN "铁爪锁喉" HIR "」直取$n" HIR "颈部。\n" NOR;
      #         me->add("neili", -20);
      # 
      #         ap = me->query_skill("claw");
      #         dp = target->query_skill("dodge");
      # 
      #         if (ap / 2 + random(ap * 2 / 3) > dp)
      #         {
      #                 damage = 0;
      # 
      #                 if (me->query("max_neili") > target->query("max_neili") * 2)
      #                 {
      #                         msg += HIR "霎时只听「喀嚓」一声脆响，$N" HIR "五"
      #                                "指竟将$n" HIR "的喉结捏个粉碎。\n" NOR "("
      #                                " $n" RED "受伤过重，已经有如风中残烛，随时"
      #                                "都可能断气。" NOR ")\n";
      # 
      #                         damage = -1;
      #                         me->start_busy(1);
      #                         me->add("neili", -50);
      # 
      #                 } else
      #                 {
      #                         target->start_busy(1 + random(3));
      #         
      #                         damage = ap + (int)me->query_skill("force");
      #                         damage = damage / 2 + random(damage / 2);
      #                         
      #                         if (arrayp(limbs = target->query("limbs")))
      #                                 limb = limbs[random(sizeof(limbs))];
      #                         else
      #                                 limb = "要害";
      # 
      #                         msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 75,
      #                                                    HIR "$n" HIR "慌忙躲闪，却听「喀嚓」一"
      #                                                    "声，$N" HIR "五指正拿中$n" HIR "的" +
      #                                                    limb + "。\n" NOR);
      #                         me->start_busy(3);
      #                         me->add("neili", -180);
      #                 }
      #         } else 
      #         {
      #                 msg += CYN "可是$n" CYN "看破了$P"
      #                        CYN "的企图，身形急动，躲开了这一抓。\n"NOR;
      #                 me->start_busy(4);
      #                 me->add("neili", -100);
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         if (damage < 0)
      #                 target->die(me);
      # 
      #         return 1;
      # }
end
