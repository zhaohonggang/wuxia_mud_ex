defmodule Kantele.Combat.Skills.Performs.XianglongZhang.Hui do
  @moduledoc """
  perform「亢龙有悔」（source xianglong-zhang/hui.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "strike"}, {"dp", "dodge"}, {"dp", "force"}, {"dp", "parry"}], "level_gates": [{"force", "380"}, {"xianglong-zhang", "250"}], "map_gates": [{"strike", "xianglong-zhang"}], "prepared_gates": [{"strike", "xianglong-zhang"}], "resource_gates": [{"max_neili", "6000"}, {"neili", "1000"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你内功修为不够，难以施展", "你内力修为不够，难以施展", "你降龙十八掌火候不够，难以施展", "你没有激发降龙十八掌，难以施展", "你没有准备降龙十八掌，难以施展", "你现在真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("strike") + me->query("str") * 10", "dp_formula": "target->query_skill("force") + target->query("con") * 10"}, "color_codes": ["HIC", "HIR", "HIW", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIC "却见$p气贯双臂，凝神应对，$P掌"
      #                         "力如泥牛入海，尽数卸去。\n" NOR", "HIC "可是$p全力抵挡招架，竟似游刃有"
      #                         "余，将$P的掌力卸于无形。\n" NOR", "HIC "$p眼见来势凶猛，身形疾退，瞬间"
      #                         "飘出三丈，脱出掌力之外。\n" NOR"], "success": ["COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 60 + random(10),
      #                                             HIR "$P身形一闪，竟已晃至$p跟前，$p躲"
      #                                             "闪不及，顿被击个正中。\n" NOR)", "COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 70 + random(10),
      #                                             HIR "$p一声惨嚎，被$P这一掌击中胸前，"
      #                                             "喀嚓喀嚓断了几根肋骨。\n" NOR)", "COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 80 + random(10),
      #                                             HIR "结果$p躲闪不及，$P掌劲顿时穿胸而"
      #                                             "过，顿时口中鲜血狂喷。\n" NOR)"]}, "damage_formula": %{"formula": "ap + random(ap / 2)"}, "hit_formula": %{"left_side": "ap * 2 / 3 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-400 - random(400)"}, {"neili", "-400 - random(600)"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(3 + random(4));"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3 + random(4));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define HUI "「" HIR "亢龙有悔" NOR "」"
      # #define HUIP "「" HIR "亢龙有悔" HIW "」"
      # #define HUIZ "「" HIY "真·亢龙有悔" HIY "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         int damage;
      #         string msg;
      #         int ap, dp;
      #         float improve;
      #         improve = 0;
      # 
      #         if (userp(me) && ! me->query("can_perform/xianglong-zhang/hui"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(HUI "只能对战斗中的对手使用。\n");
      # 
      #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
      #                 return notify_fail(HUI "只能空手使用。\n");
      # 
      #         if ((int)me->query_skill("force") < 380)
      #                 return notify_fail("你内功修为不够，难以施展" HUI "。\n");
      # 
      #         if ((int)me->query("max_neili") < 6000)
      #                 return notify_fail("你内力修为不够，难以施展" HUI "。\n");
      # 
      #         if ((int)me->query_skill("xianglong-zhang", 1) < 250)
      #                 return notify_fail("你降龙十八掌火候不够，难以施展" HUI "。\n");
      # 
      #         if (me->query_skill_mapped("strike") != "xianglong-zhang")
      #                 return notify_fail("你没有激发降龙十八掌，难以施展" HUI "。\n");
      # 
      #         if (me->query_skill_prepared("strike") != "xianglong-zhang")
      #                 return notify_fail("你没有准备降龙十八掌，难以施展" HUI "。\n");
      # 
      #         if ((int)me->query("neili") < 1000)
      #                 return notify_fail("你现在真气不够，难以施展" HUI "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         if (me->query("family/family_name") == "丐帮")
      #         {
      #             message_sort( HIY "\n$N" HIY "施展出丐帮绝学 " HUIZ "\n" NOR, me, target);
      #             improve += 10 / 100;
      #         }
      # 
      #         // 第一掌
      #         //ap = me->query_skill("strike") + me->query("str") * 5;
      #         //dp = target->query_skill("dodge") + target->query("dex") * 5;
      #          ap = me->query_skill("strike") + me->query("str") * 10;
      #          dp = target->query_skill("dodge") + target->query("dex") * 10;
      #          ap += ap * improve;
      # 
      #         message_sort(HIW "\n忽然$N" HIW "身形激进，左手一划，右手呼的一掌"
      #                      "拍向$n" HIW "，正是降龙十八掌" HUIP "。力自掌生之际"
      #                      "说到便到，以排山倒海之势向$n" HIW "狂涌而去，当真石"
      #                      "破天惊，威力无比。\n" NOR, me, target);
      # 
      #         if (ap * 2 / 3 + random(ap) > dp)
      #         {
      #                 damage = ap + random(ap / 2);
      #                 msg = COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 60 + random(10),
      #                                           HIR "$P身形一闪，竟已晃至$p跟前，$p躲"
      #                                           "闪不及，顿被击个正中。\n" NOR);
      #         } else
      #         {
      #                 msg = HIC "却见$p气贯双臂，凝神应对，$P掌"
      #                       "力如泥牛入海，尽数卸去。\n" NOR;
      #         }
      #         message_vision(msg, me, target);
      # 
      #         // 第二掌
      #         ap = me->query_skill("strike") + me->query("str") * 10;
      #         dp = target->query_skill("parry") + target->query("int") * 10;
      #         ap += ap * improve;
      # 
      #         message_sort(HIW "\n$N" HIW "一掌既出，身子已然抢到离$n" HIW "三"
      #                      "四丈之外，后掌推前掌两股掌力道合并，又是一招" HUIP
      #                      "攻出，掌力犹如怒潮狂涌，势不可当。霎时$p便觉气息窒"
      #                      "滞，立足不稳。\n" NOR, me, target);
      # 
      #         if (ap * 3 / 5 + random(ap) > dp)
      #         {
      #                 damage = ap + random(ap / 2);
      #                 msg = COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 70 + random(10),
      #                                           HIR "$p一声惨嚎，被$P这一掌击中胸前，"
      #                                           "喀嚓喀嚓断了几根肋骨。\n" NOR);
      #         } else
      #         {
      #                 msg = HIC "可是$p全力抵挡招架，竟似游刃有"
      #                       "余，将$P的掌力卸于无形。\n" NOR;
      #         }
      #         message_vision(msg, me, target);
      # 
      #         // 第三掌
      #         ap = me->query_skill("strike") + me->query("str") * 10;
      #         dp = target->query_skill("force") + target->query("con") * 10;
      #         ap += ap * improve;
      # 
      #         message_sort(HIW "\n紧跟着$N" HIW "右掌斜挥，前招掌力未消，此招掌"
      #                      "力又到，竟然又攻出一招" HUIP "，掌夹风势，势如破竹，"
      #                      "便如一堵无形气墙，向前疾冲而去。$n" HIW "只觉气血翻"
      #                      "涌，气息沉浊。\n" NOR, me, target);
      # 
      #         if (ap *11 / 20 + random(ap) > dp)
      #         {
      #                 damage = ap + random(ap);
      #                 msg = COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 80 + random(10),
      #                                           HIR "结果$p躲闪不及，$P掌劲顿时穿胸而"
      #                                           "过，顿时口中鲜血狂喷。\n" NOR);
      #         } else
      #         {
      #                 msg = HIC "$p眼见来势凶猛，身形疾退，瞬间"
      #                       "飘出三丈，脱出掌力之外。\n" NOR;
      #         }
      #         message_vision(msg, me, target);
      #         me->start_busy(3 + random(4));
      #         //me->add("neili", -400 - random(600));
      #         me->add("neili", -400 - random(400));
      #         return 1;
      # }
end
