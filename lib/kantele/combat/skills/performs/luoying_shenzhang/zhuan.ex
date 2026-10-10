defmodule Kantele.Combat.Skills.Performs.LuoyingShenzhang.Zhuan do
  @moduledoc """
  perform「奇门五转」（source luoying-shenzhang/zhuan.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "luoying-shenzhang"}, {"damage", "force"}, {"dp", "dodge"}], "level_gates": [{"force", "180"}, {"luoying-shenzhang", "120"}, {"qimen-wuxing", "120"}], "map_gates": [{"strike", "luoying-shenzhang"}], "prepared_gates": [{"strike", "luoying-shenzhang"}], "resource_gates": [{"neili", "300"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的落英神剑掌不够娴熟，难以施展", "你对奇门五行的研究不够，难以施展", "你没有激发落英神剑掌，难以施展", "你没有准备落英神剑掌，难以施展", "你的内功火候不足，难以施展", "你现在的内力不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "(int)me->query_skill("luoying-shenzhang", 1) +
      #                (int)me->query_skill("qimen-wuxing", 1) +
      #                (int)me->query_skill("force") +
      #                (int)me->query("int") * 10", "dp_formula": "(int)target->query_skill("dodge") +
      #                (int)target->query_skill("parry") +
      #                (int)target->query_skill("qimen-wuxing", 1) +
      #                (int)target->query("int") * 10"}, "color_codes": ["HIC", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "$N" HIY "掌势陡然一变，施出落英神剑掌「奇门五转」绝技，虚虚"
      #                 "实实的攻向$n" HIY "。\n" NOR", "= HIC "可是$p" HIC "看破了$P" HIC "的企图，连消带打，避开了$P"
      #                          HIC "这一击。\n"NOR"], "success": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 30,
      #                                              HIR "$n" HIR "大吃一惊，登时接连中掌，"
      #                                              "狂喷出一口鲜血，身子急转个不停。\n" NOR)"]}, "damage_formula": %{"formula": "(int)me->query_skill("force") + (int)me->query_skill("strike")"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-150"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-150"}], "affect_by": [], "apply_adds": [], "busy_lines": ["target->start_busy(2 + random(3));", "me->start_busy(2);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - target->start_busy(2 + random(3));
      #   - me->start_busy(2);
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define ZHUAN "「" HIY "奇门五转" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         int damage;
      #         string msg;
      #         int ap, dp;
      # 
      #         if (userp(me) && ! me->query("can_perform/luoying-shenzhang/zhuan"))
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
      #         if ((int)me->query_skill("luoying-shenzhang", 1) < 120)
      #                 return notify_fail("你的落英神剑掌不够娴熟，难以施展" ZHUAN "。\n");
      # 
      #         if ((int)me->query_skill("qimen-wuxing", 1) < 120)
      #                 return notify_fail("你对奇门五行的研究不够，难以施展" ZHUAN "。\n");
      # 
      #         if (me->query_skill_mapped("strike") != "luoying-shenzhang")
      #                 return notify_fail("你没有激发落英神剑掌，难以施展" ZHUAN "。\n");
      # 
      #         if (me->query_skill_prepared("strike") != "luoying-shenzhang")
      #                 return notify_fail("你没有准备落英神剑掌，难以施展" ZHUAN "。\n");
      # 
      #         if ((int)me->query_skill("force") < 180)
      #                 return notify_fail("你的内功火候不足，难以施展" ZHUAN "。\n");
      # 
      #         if ((int)me->query("neili") < 300)
      #                 return notify_fail("你现在的内力不够，难以施展" ZHUAN "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIY "$N" HIY "掌势陡然一变，施出落英神剑掌「奇门五转」绝技，虚虚"
      #               "实实的攻向$n" HIY "。\n" NOR;
      # 
      #         ap = (int)me->query_skill("luoying-shenzhang", 1) +
      #              (int)me->query_skill("qimen-wuxing", 1) +
      #              (int)me->query_skill("force") +
      #              (int)me->query("int") * 10;
      # 
      #         dp = (int)target->query_skill("dodge") +
      #              (int)target->query_skill("parry") +
      #              (int)target->query_skill("qimen-wuxing", 1) +
      #              (int)target->query("int") * 10;
      # 
      #         me->add("neili", -150);
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 target->start_busy(2 + random(3));
      #             me->start_busy(2);
      #                 damage = (int)me->query_skill("force") + (int)me->query_skill("strike");
      #                 damage = damage / 4;
      #                 damage += random(damage);
      # 
      #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 30,
      #                                            HIR "$n" HIR "大吃一惊，登时接连中掌，"
      #                                            "狂喷出一口鲜血，身子急转个不停。\n" NOR);
      #         } else
      #     {
      #             me->start_busy(3);
      #                 msg += HIC "可是$p" HIC "看破了$P" HIC "的企图，连消带打，避开了$P"
      #                        HIC "这一击。\n"NOR;
      #     }
      #         message_vision(msg, me, target);
      #         return 1;
      # }
end
