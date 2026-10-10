defmodule Kantele.Combat.Skills.Performs.BaihuaCuoquan.Hong do
  @moduledoc """
  perform「战神轰天诀」（source baihua-cuoquan/hong.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "unarmed"}, {"dp", "parry"}], "level_gates": [{"baihua-cuoquan", "250"}, {"zhanshen-xinjing", "250"}], "map_gates": [{"force", "zhanshen-xinjing"}, {"unarmed", "baihua-cuoquan"}], "prepared_gates": [{"unarmed", "baihua-cuoquan"}], "resource_gates": [{"max_neili", "5000"}, {"neili", "800"}], "var_gates": [{"damage", "0"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的百花错拳不够娴熟，难以施展", "你的战神心经修为不够，难以施展", "你的内力修为不足，难以施展", "你没有激发百花错拳，难以施展", "你没有激发战神心经，难以施展", "你没有准备百花错拳，难以施展", "你的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("unarmed") +
      #                me->query_skill("force")", "dp_formula": "target->query_skill("parry") +
      #                target->query_skill("dodge")"}, "color_codes": ["CYN", "HIR", "HIW", "HIY", "NOR", "RED"], "combat_exp_formulas": [{"lvls", "to_int(pow(to_float(me->query("combat_exp") * 10), 1.0 / 3))"}], "combat_messages": %{"fail": [], "other": ["HIW "$N" HIW "一声怒嚎，将战神心经提运极至，双拳顿时携着"
      #                 "雷霆万钧之势猛贯向$n" HIW "。\n" NOR", "= CYN "可是$p" CYN "识破了$P"
      #                          CYN "这一招，斜斜一跃避开。\n" NOR"], "success": ["= HIR "只见$N" HIR "一拳轰至，便将$n" HIR "震得"
      #                                  "心脉俱碎，仰天喷出一口鲜血，软软瘫倒。\n" NOR
      #                                  "( $n" RED "受伤过重，已经有如风中残烛，随时都"
      #                                  "可能断气。" NOR ")\n"", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 150,
      #                                                  HIR "结果$p" HIR "闪避不及，$P" HIR "的"
      #                                                      "拳力掌劲顿时透体而入，口中鲜血狂喷，连"
      #                                                      "退数步。\n" NOR)"]}, "damage_formula": %{"formula": "0"}, "hit_formula": %{"left_side": "ap * 3 / 5 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}, {"neili", "-150"}, {"neili", "-400"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-150"}, {"neili", "-400"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(4);", "me->start_busy(5);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(4);
      #   - me->start_busy(5);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define HONG "「" HIY "战神轰天诀" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      # //      object weapon;
      #         int ap, dp, damage;
      #         string msg;
      # 
      #         float improve;
      #         int lvls, m, n;
      #         string martial;
      #         string *ks;
      #         martial = "unarmed";
      # 
      #         if (userp(me) && ! me->query("can_perform/baihua-cuoquan/hong"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(HONG "只能对战斗中的对手使用。\n");
      # 
      #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
      #                 return notify_fail(HONG "只能空手施展。\n");
      # 
      #         if ((int)me->query_skill("baihua-cuoquan", 1) < 250)
      #                 return notify_fail("你的百花错拳不够娴熟，难以施展" HONG "。\n");
      # 
      #         if ((int)me->query_skill("zhanshen-xinjing", 1) < 250)
      #                 return notify_fail("你的战神心经修为不够，难以施展" HONG "。\n");
      # 
      #         if (me->query("max_neili") < 5000)
      #                 return notify_fail("你的内力修为不足，难以施展" HONG "。\n");
      # 
      #         if (me->query_skill_mapped("unarmed") != "baihua-cuoquan")
      #                 return notify_fail("你没有激发百花错拳，难以施展" HONG "。\n");
      # 
      #         if (me->query_skill_mapped("force") != "zhanshen-xinjing")
      #                 return notify_fail("你没有激发战神心经，难以施展" HONG "。\n");
      # 
      #         if (me->query_skill_prepared("unarmed") != "baihua-cuoquan")
      #                 return notify_fail("你没有准备百花错拳，难以施展" HONG "。\n");
      # 
      #         if (me->query("neili") < 800)
      #                 return notify_fail("你的真气不够，难以施展" HONG "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIW "$N" HIW "一声怒嚎，将战神心经提运极至，双拳顿时携着"
      #               "雷霆万钧之势猛贯向$n" HIW "。\n" NOR;
      # 
      #         lvls = to_int(pow(to_float(me->query("combat_exp") * 10), 1.0 / 3));
      #         lvls = lvls * 4 / 5;
      #         ks = keys(me->query_skills(martial));
      #         improve = 0;
      #         n = 0;
      #         //最多给予5个技能的加成
      #         for (m = 0; m < sizeof(ks); m++)
      #         {
      #             if (SKILL_D(ks[m])->valid_enable(martial))
      #             {
      #                 n += 1;
      #                 improve += (int)me->query_skill(ks[m], 1);
      #                 if (n > 4 )
      #                     break;
      #             }
      #         }
      # 
      #         improve = improve * 4 / 100 / lvls;
      # 
      #         ap = me->query_skill("unarmed") +
      #              me->query_skill("force");
      #         ap += ap * improve;
      # 
      #         dp = target->query_skill("parry") +
      #              target->query_skill("dodge");
      # 
      #         if (ap * 3 / 5 + random(ap) > dp)
      #         {
      #                 damage = 0;
      #                 if (me->query("max_neili") > target->query("max_neili") * 2)
      #                 {
      #                     me->start_busy(2);
      #                         me->add("neili", -100);
      #                         msg += HIR "只见$N" HIR "一拳轰至，便将$n" HIR "震得"
      #                                "心脉俱碎，仰天喷出一口鲜血，软软瘫倒。\n" NOR
      #                                "( $n" RED "受伤过重，已经有如风中残烛，随时都"
      #                                "可能断气。" NOR ")\n";
      #                         damage = -1;
      #                 } else
      #                 {
      #                     me->start_busy(4);
      #                     me->add("neili", -400);
      #                     damage = ap * 2 / 3 + random(ap);
      #                     msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 150,
      #                                                HIR "结果$p" HIR "闪避不及，$P" HIR "的"
      #                                                    "拳力掌劲顿时透体而入，口中鲜血狂喷，连"
      #                                                    "退数步。\n" NOR);
      #                 }
      #         } else
      #         {
      #                 me->start_busy(5);
      #                 me->add("neili", -150);
      #                 msg += CYN "可是$p" CYN "识破了$P"
      #                        CYN "这一招，斜斜一跃避开。\n" NOR;
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         if (damage < 0)
      #                 target->die(me);
      # 
      #         return 1;
      # }
end
