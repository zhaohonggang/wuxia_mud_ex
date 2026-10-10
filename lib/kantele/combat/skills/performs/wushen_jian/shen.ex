defmodule Kantele.Combat.Skills.Performs.WushenJian.Shen do
  @moduledoc """
  perform「五神朝元势」（source wushen-jian/shen.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "wushen-jian"}, {"damage", "wushen-jian"}, {"dp", "dodge"}], "level_gates": [{"dodge", "200"}, {"force", "220"}, {"wushen-jian", "240"}], "map_gates": [{"sword", "wushen-jian"}], "prepared_gates": [], "resource_gates": [{"max_neili", "5500"}, {"neili", "500"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你衡山五神剑不够娴熟，难以施展", "你没有激发衡山五神剑，难以施展", "你的内功火候不够，难以施展", "你的轻功火候不够，难以施展", "你的内力修为不足，难以施展", "你现在的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("wushen-jian", 1) +
      #            me->query_skill("martial-cognize", 1)", "dp_formula": "target->query_skill("dodge", 1) +
      #            target->query_skill("martial-cognize", 1)"}, "color_codes": ["CYN", "HIG", "HIM", "HIR", "HIW", "HIY", "NOR", "WHT"], "combat_messages": %{"fail": [], "other": ["COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 80,
      #                                         HIG "\n$n" HIG "见$N" HIG "五道剑光剑势"
      #                                             "惊人，急忙收敛心神奋力招架。哪知$P这"
      #                                             "招力道非凡，$p一声闷哼，连退几步，喷"
      #                                             "出一口鲜血。\n" NOR)", "CYN "\n然而$n" CYN "以快对快，飞身一跳"
      #                     "已然躲过$N" CYN "这一招。\n" NOR"], "success": ["HIM "\n$N" HIM "一声怒喝，内劲暴涨，手中" + wn +
      #             HIM "变幻万千，霎那间化作红黄蓝绿白五道剑光，纵"
      #                 "横飞扬。$P身法蓦地变快，随着剑光同时将『" HIR
      #                 "祝融" HIM "』、『" HIY "紫盖" HIM "』、『" NOR
      #                 WHT "石廪" HIM "』、『" HIG "芙蓉" HIM "』、『" HIW "天柱" HIM "』五套剑法交替使出，电光火石间"
      #                 "已袭向$n" HIM "全身。\n" NOR", "COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 100 + random(10),
      #                                         HIR "\n$n" HIR "见$N" HIR "五道剑光缤纷"
      #                                             "洒落，交错纵横，呼啸着向自己袭来。心"
      #                                             "底不由大惊，登时听得“噗嗤”一声，剑"
      #                                             "气透体而过。\n" NOR)"]}, "damage_formula": %{"formula": "me->query_skill("wushen-jian", 1) +
      #                    me->query_skill("force", 1) +
      #                    me->query_skill("martial-cognize", 1)"}, "hit_formula": %{"left_side": "ap * 2 / 3 + random(ap)", "operator": ">", "right_side": "random(dp)"}, "resource_adds": [{"neili", "-150"}, {"neili", "-200"}, {"neili", "-300"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-150"}, {"neili", "-200"}, {"neili", "-300"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(3 + random(2));", "me->start_busy(3 + random(3));", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3 + random(2));
      #   - me->start_busy(3 + random(3));
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
      # #define SHEN "「" HIM "五神朝元势" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #     int damage;
      #     string msg, wn;
      #     object weapon;
      #     int ap, dp;
      #     me = this_player();
      # 
      #     if (userp(me) && !me->query("can_perform/wushen-jian/shen"))
      #         return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #     if (!target)
      #         target = offensive_target(me);
      # 
      #     if (!target || !me->is_fighting(target))
      #         return notify_fail(SHEN "只能在战斗中对对手使用。\n");
      # 
      #     if (!objectp(weapon = me->query_temp("weapon")) || (string)weapon->query("skill_type") != "sword")
      #         return notify_fail("你使用的武器不对，难以施展" SHEN "。\n");
      # 
      #     if ((int)me->query_skill("wushen-jian", 1) < 240)
      #         return notify_fail("你衡山五神剑不够娴熟，难以施展" SHEN "。\n");
      # 
      #     if (me->query_skill_mapped("sword") != "wushen-jian")
      #         return notify_fail("你没有激发衡山五神剑，难以施展" SHEN "。\n");
      # 
      #     if ((int)me->query_skill("force", 1) < 220)
      #         return notify_fail("你的内功火候不够，难以施展" SHEN "。\n");
      # 
      #     if ((int)me->query_skill("dodge", 1) < 200)
      #         return notify_fail("你的轻功火候不够，难以施展" SHEN "。\n");
      # 
      #     if ((int)me->query("max_neili") < 5500)
      #         return notify_fail("你的内力修为不足，难以施展" SHEN "。\n");
      # 
      #     if ((int)me->query("neili") < 500)
      #         return notify_fail("你现在的真气不够，难以施展" SHEN "。\n");
      # 
      #     if (!living(target))
      #         return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #     wn = weapon->name();
      # 
      #     msg = HIM "\n$N" HIM "一声怒喝，内劲暴涨，手中" + wn +
      #           HIM "变幻万千，霎那间化作红黄蓝绿白五道剑光，纵"
      #               "横飞扬。$P身法蓦地变快，随着剑光同时将『" HIR
      #               "祝融" HIM "』、『" HIY "紫盖" HIM "』、『" NOR
      #               WHT "石廪" HIM "』、『" HIG "芙蓉" HIM "』、『" HIW "天柱" HIM "』五套剑法交替使出，电光火石间"
      #               "已袭向$n" HIM "全身。\n" NOR;
      # 
      #     message_sort(msg, me, target);
      # 
      #     ap = me->query_skill("wushen-jian", 1) +
      #          me->query_skill("martial-cognize", 1);
      # 
      #     dp = target->query_skill("dodge", 1) +
      #          target->query_skill("martial-cognize", 1);
      # 
      #     if (ap * 2 / 3 + random(ap) > random(dp))
      #     {
      #         damage = me->query_skill("wushen-jian", 1) +
      #                  me->query_skill("force", 1) +
      #                  me->query_skill("martial-cognize", 1);
      # 
      #         damage += random(damage / 2);
      # 
      #         // 五分之一的几率可被招架
      #         if (random(10) <= 1 && ap / 2 < dp)
      #         {
      #             damage = damage / 3;
      # 
      #             msg = COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 80,
      #                                       HIG "\n$n" HIG "见$N" HIG "五道剑光剑势"
      #                                           "惊人，急忙收敛心神奋力招架。哪知$P这"
      #                                           "招力道非凡，$p一声闷哼，连退几步，喷"
      #                                           "出一口鲜血。\n" NOR);
      #             me->add("neili", -200);
      #             me->start_busy(3 + random(2));
      #         }
      #         else
      #         {
      #             msg = COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 100 + random(10),
      #                                       HIR "\n$n" HIR "见$N" HIR "五道剑光缤纷"
      #                                           "洒落，交错纵横，呼啸着向自己袭来。心"
      #                                           "底不由大惊，登时听得“噗嗤”一声，剑"
      #                                           "气透体而过。\n" NOR);
      #             me->add("neili", -300);
      #             me->start_busy(3 + random(3));
      #         }
      #     }
      #     else
      #     {
      #         msg = CYN "\n然而$n" CYN "以快对快，飞身一跳"
      #                   "已然躲过$N" CYN "这一招。\n" NOR;
      #         me->add("neili", -150);
      #         me->start_busy(3);
      #     }
      #     message_sort(msg, me, target);
      #     return 1;
      # }
end
