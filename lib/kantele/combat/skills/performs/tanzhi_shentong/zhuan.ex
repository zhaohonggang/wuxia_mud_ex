defmodule Kantele.Combat.Skills.Performs.TanzhiShentong.Zhuan do
  @moduledoc """
  perform「转乾坤」（source tanzhi-shentong/zhuan.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "finger"}, {"count", "mathematics"}, {"dp", "force"}], "level_gates": [{"qimen-wuxing", "200"}, {"tanzhi-shentong", "220"}], "map_gates": [{"finger", "tanzhi-shentong"}], "prepared_gates": [{"finger", "tanzhi-shentong"}], "resource_gates": [{"max_neili", "3500"}, {"neili", "800"}], "var_gates": [{"damage", "0"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的弹指神通不够娴熟，难以施展", "你的奇门五行修为不够，难以施展", "你没有激发弹指神通，难以施展", "你没有准备弹指神通，难以施展", "你的内力修为不足，难以施展", "你现在的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("finger") +
      #                me->query_skill("qimen-wuxing", 1) +
      #                me->query_skill("tanzhi-shentong", 1)", "dp_formula": "target->query_skill("force") +
      #                target->query_skill("parry", 1) +
      #                target->query_skill("qimen-wuxing", 1)"}, "color_codes": ["CYN", "HIC", "HIR", "HIW", "NOR", "RED"], "combat_exp_formulas": [{"lvls", "to_int(pow(to_float(me->query("combat_exp") * 10), 1.0 / 3))"}], "combat_messages": %{"fail": [], "other": ["= CYN "$p" CYN "见$P" CYN "招式奇特，不感大"
      #                          "意，顿时向后跃数丈，躲闪开来。\n" NOR"], "success": ["HIC "$N" HIC "将全身功力聚于一指，指劲按照二十八宿方位云贯而出，正"
      #                 "是桃花岛「" HIR "转乾坤" HIC "」绝技。\n" NOR", "= HIR "霎那间$n" HIR "只见寒芒一闪，$N" HIR "食指"
      #                                  "已钻入$p" HIR "印堂半尺，指劲顿时破脑而入。\n"
      #                                  HIW "你听到“噗”的一声，身上竟然溅到几滴脑浆！"
      #                                  "\n" NOR "( $n" RED "受伤过重，已经有如风中残烛"
      #                                  "，随时都可能断气。" NOR ")\n"", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, (100 + random(count/10)),
      #                                                  HIR "霎那间$n" HIR "只见寒芒一闪，$N"
      #                                                      HIR "食指已钻入$p" HIR "胸堂半尺，指劲"
      #                                                      "顿时破体而入。\n你听到“嗤”的一声，"
      #                                                      "身上竟然溅到几滴鲜血！\n" NOR)"]}, "damage_formula": %{"formula": "0"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-(200 + random(count))"}, {"neili", "-200"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-200"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);", "me->start_busy(2);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(3);
      #   - me->start_busy(2);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define ZHUAN "「" HIR "转乾坤" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      # //      object weapon;
      #         int ap, dp, damage, count;
      #         string msg;
      # 
      #         float improve;
      #         int lvls, m, n;
      #         string martial;
      #         string *ks;
      #         martial = "finger";
      # 
      #         if (userp(me) && ! me->query("can_perform/tanzhi-shentong/zhuan"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(ZHUAN "只能对战斗中的对手使用。\n");
      # 
      #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
      #                 return notify_fail(ZHUAN "只能空手施展。\n");
      # 
      #         if ((int)me->query_skill("tanzhi-shentong", 1) < 220)
      #                 return notify_fail("你的弹指神通不够娴熟，难以施展" ZHUAN "。\n");
      # 
      #         if ((int)me->query_skill("qimen-wuxing", 1) < 200)
      #                 return notify_fail("你的奇门五行修为不够，难以施展" ZHUAN "。\n");
      # 
      #         if (me->query_skill_mapped("finger") != "tanzhi-shentong")
      #                 return notify_fail("你没有激发弹指神通，难以施展" ZHUAN "。\n");
      # 
      #         if (me->query_skill_prepared("finger") != "tanzhi-shentong")
      #                 return notify_fail("你没有准备弹指神通，难以施展" ZHUAN "。\n");
      # 
      #         if (me->query("max_neili") < 3500)
      #                 return notify_fail("你的内力修为不足，难以施展" ZHUAN "。\n");
      # 
      #         if (me->query("neili") < 800)
      #                 return notify_fail("你现在的真气不够，难以施展" ZHUAN "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIC "$N" HIC "将全身功力聚于一指，指劲按照二十八宿方位云贯而出，正"
      #               "是桃花岛「" HIR "转乾坤" HIC "」绝技。\n" NOR;
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
      #         improve = improve * 5 / 100 / lvls;
      # 
      #         ap = me->query_skill("finger") +
      #              me->query_skill("qimen-wuxing", 1) +
      #              me->query_skill("tanzhi-shentong", 1);
      # 
      #         dp = target->query_skill("force") +
      #              target->query_skill("parry", 1) +
      #              target->query_skill("qimen-wuxing", 1);
      #         count = me->query_skill("mathematics", 1);
      #         ap += ap * improve;
      # 
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 damage = 0;
      #                 if (me->query("max_neili") > target->query("max_neili") * 2)
      #                 {
      #                     me->start_busy(2);
      #                         msg += HIR "霎那间$n" HIR "只见寒芒一闪，$N" HIR "食指"
      #                                "已钻入$p" HIR "印堂半尺，指劲顿时破脑而入。\n"
      #                                HIW "你听到“噗”的一声，身上竟然溅到几滴脑浆！"
      #                                "\n" NOR "( $n" RED "受伤过重，已经有如风中残烛"
      #                                "，随时都可能断气。" NOR ")\n";
      #                         damage = -1;
      #                 } else
      #         {
      #                     me->start_busy(3);
      #                     damage = ap + random(ap);
      #                     me->add("neili", -(200 + random(count)));
      #                     msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, (100 + random(count/10)),
      #                                                HIR "霎那间$n" HIR "只见寒芒一闪，$N"
      #                                                    HIR "食指已钻入$p" HIR "胸堂半尺，指劲"
      #                                                    "顿时破体而入。\n你听到“嗤”的一声，"
      #                                                    "身上竟然溅到几滴鲜血！\n" NOR);
      #         }
      #         } else
      #         {
      #                 me->start_busy(2);
      #                 me->add("neili", -200);
      #                 msg += CYN "$p" CYN "见$P" CYN "招式奇特，不感大"
      #                        "意，顿时向后跃数丈，躲闪开来。\n" NOR;
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         if (damage < 0)
      #                 target->die(me);
      # 
      #         return 1;
      # }
end
