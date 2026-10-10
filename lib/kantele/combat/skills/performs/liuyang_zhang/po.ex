defmodule Kantele.Combat.Skills.Performs.LiuyangZhang.Po do
  @moduledoc """
  perform「破神诀」（source liuyang-zhang/po.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "force"}, {"dp", "force"}], "level_gates": [{"bahuang-gong", "220"}, {"liuyang-zhang", "220"}], "map_gates": [{"force", "bahuang-gong"}, {"strike", "liuyang-zhang"}], "prepared_gates": [{"strike", "liuyang-zhang"}], "resource_gates": [{"max_neili", "3500"}, {"neili", "800"}], "var_gates": [{"damage", "0"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你八荒六合唯我独尊功火候不够，难以施展", "你的天山六阳掌不够娴熟，难以施展", "你的内力修为不足，难以施展", "你没有激发天山六阳掌，难以施展", "你没有准备天山六阳掌，难以施展", "你没有激发八荒六合唯我独尊功，难以施展", "你现在真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("force") + me->query_skill("strike")", "dp_formula": "target->query_skill("force") + target->query_skill("parry")"}, "color_codes": ["CYN", "HIR", "NOR", "RED"], "combat_exp_formulas": [{"lvl", "to_int(pow(to_float(me->query("combat_exp") * 10), 1.0 / 3))"}], "combat_messages": %{"fail": [], "other": ["= CYN "$p" CYN "见$P" CYN "掌劲澎湃，决计抵挡不"
      #                          "住，当即身子向后横丈许，躲闪开来。\n" NOR"], "success": ["HIR "$N" HIR "将八荒六合唯我独尊功提运至极限，全身真气迸发，呼的一掌"
      #                 "向$n" HIR "头顶猛然贯落。\n" NOR", "= HIR "顿时只听“噗”的一声，$N" HIR "一掌将$n"
      #                                  HIR "头骨拍得粉碎，脑浆四溅，当即瘫了下去。\n"
      #                                  NOR "( $n" RED "受伤过重，已经有如风中残烛，"
      #                                  "随时都可能断气。" NOR ")\n"", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 90,
      #                                                  HIR "$n" HIR "慌忙抵挡，可已然不及，$N"
      #                                                      HIR "掌劲如洪水般涌入体内，接连震断数根"
      #                                                      "肋骨。\n:内伤@?")"]}, "damage_formula": %{"formula": "0"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-380"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-380"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(1 + random(3));", "me->start_busy(1 + random(4));"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1 + random(3));
      #   - me->start_busy(1 + random(4));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define PO "「" HIR "破神诀" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      # //        object weapon;
      #         int damage;
      #         string msg;
      #         int ap, dp;
      #         //me = this_player();
      # 
      #         float improve;
      #         int lvl, m, n;
      #         string martial;
      #         string *ks;
      #         martial = "strike";
      #         me = this_player();
      # 
      #         if (userp(me) && ! me->query("can_perform/liuyang-zhang/po"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target)
      #         {
      #             me->clean_up_enemy();
      #             target = me->select_opponent();
      #         }
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(PO "只能对战斗中的对手使用。\n");
      # 
      #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
      #                 return notify_fail(PO "只能空手施展。\n");
      # 
      #         if ((int)me->query_skill("bahuang-gong", 1) < 220)
      #                 return notify_fail("你八荒六合唯我独尊功火候不够，难以施展" PO "。\n");
      # 
      #         if ((int)me->query_skill("liuyang-zhang", 1) < 220)
      #                 return notify_fail("你的天山六阳掌不够娴熟，难以施展" PO "。\n");
      # 
      #         if (me->query("max_neili") < 3500)
      #                 return notify_fail("你的内力修为不足，难以施展" PO "。\n");
      # 
      #         if (me->query_skill_mapped("strike") != "liuyang-zhang")
      #                 return notify_fail("你没有激发天山六阳掌，难以施展" PO "。\n");
      # 
      #         if (me->query_skill_prepared("strike") != "liuyang-zhang")
      #                 return notify_fail("你没有准备天山六阳掌，难以施展" PO "。\n");
      # 
      #         if (me->query_skill_mapped("force") != "bahuang-gong")
      #                 return notify_fail("你没有激发八荒六合唯我独尊功，难以施展" PO "。\n");
      # 
      #         if (me->query("neili") < 800)
      #                 return notify_fail("你现在真气不足，难以施展" PO "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIR "$N" HIR "将八荒六合唯我独尊功提运至极限，全身真气迸发，呼的一掌"
      #               "向$n" HIR "头顶猛然贯落。\n" NOR;
      # 
      #         lvl = to_int(pow(to_float(me->query("combat_exp") * 10), 1.0 / 3));
      #         lvl = lvl * 4 / 5;
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
      #         improve = improve * 4 / 100 / lvl;
      # 
      #         me->add("neili", -380);
      #         ap = me->query_skill("force") + me->query_skill("strike");
      #         dp = target->query_skill("force") + target->query_skill("parry");
      #         ap += ap * improve;
      #         if (me->query("family/family_name") == "灵鹫宫")
      #             ap += ap / 10;
      #         if (target->is_good()) ap += ap / 10;
      # 
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 damage = 0;
      #                 if (me->query("max_neili") > target->query("max_neili") * 2)
      #                 {
      #                         msg += HIR "顿时只听“噗”的一声，$N" HIR "一掌将$n"
      #                                HIR "头骨拍得粉碎，脑浆四溅，当即瘫了下去。\n"
      #                                NOR "( $n" RED "受伤过重，已经有如风中残烛，"
      #                                "随时都可能断气。" NOR ")\n";
      #                         damage = -1;
      #                 } else
      #             {
      #             //damage = ap * 2 / 3;
      #                     damage = ap + random(ap / 2);
      # 
      #                     msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 90,
      #                                                HIR "$n" HIR "慌忙抵挡，可已然不及，$N"
      #                                                    HIR "掌劲如洪水般涌入体内，接连震断数根"
      #                                                    "肋骨。\n:内伤@?");
      #             }
      #             me->start_busy(1 + random(3));
      #         } else
      #         {
      #             msg += CYN "$p" CYN "见$P" CYN "掌劲澎湃，决计抵挡不"
      #                        "住，当即身子向后横丈许，躲闪开来。\n" NOR;
      #             me->start_busy(1 + random(4));
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         if (damage < 0)
      #                 target->die(me);
      # 
      #     return 1;
      # }
end
