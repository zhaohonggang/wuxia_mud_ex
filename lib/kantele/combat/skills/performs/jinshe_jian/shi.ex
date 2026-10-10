defmodule Kantele.Combat.Skills.Performs.JinsheJian.Shi do
  @moduledoc """
  perform「金蛇噬天」（source jinshe-jian/shi.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "jinshe-jian"}, {"damage", "jinshe-jian"}, {"dp", "dodge"}], "level_gates": [{"dodge", "240"}, {"force", "240"}, {"jinshe-jian", "200"}], "map_gates": [{"sword", "jinshe-jian"}], "prepared_gates": [], "resource_gates": [{"max_neili", "4500"}, {"neili", "400"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你金蛇剑法不够娴熟，难以施展", "你没有激发金蛇剑法，难以施展", "你的内功火候不够，难以施展", "你的轻功火候不够，难以施展", "你的内力修为不足，难以施展", "你现在的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("jinshe-jian", 1) +
      #                me->query_skill("martial-cognize", 1)", "dp_formula": "target->query_skill("dodge", 1) +
      #                target->query_skill("martial-cognize", 1)"}, "color_codes": ["CYN", "HIG", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "一道金光划过，$N" HIY "消失得无影无踪，猛然间只见一条"
      #                 "金蛇从天而下，" + weapon->name() + HIY "已将$n" HIY "笼罩。\n" NOR", "COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,
      #                                                     HIG "$n" HIG "见$N" HIG "一道金光闪过"
      #                                                     "，急忙收敛心神奋力招架。哪知$P这"
      #                                                     "招力道非凡，$p一声闷哼，连退几步，喷"
      #                                                     "出一口鲜血。\n" NOR)", "CYN "\n然而$n" CYN "以快对快，飞身一跳"
      #                         "已然躲过$N" CYN "这一招。\n" NOR"], "success": ["COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 85,
      #                                                     HIR "$n" HIR "见$N" HIR "金光划过，心"
      #                                                     "底不由大惊，登时听得“噗嗤”一声，剑"
      #                                                     "气透体而过。\n" NOR)"]}, "damage_formula": %{"formula": "me->query_skill("jinshe-jian", 1) +
      #                            me->query_skill("force", 1) +
      #                            me->query_skill("martial-cognize", 1)"}, "hit_formula": %{"left_side": "ap * 2 / 3 + random(ap)", "operator": ">", "right_side": "random(dp)"}, "resource_adds": [{"neili", "-150"}, {"neili", "-200"}, {"neili", "-300"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-150"}, {"neili", "-200"}, {"neili", "-300"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(3 + random(2));", "me->start_busy(2 + random(3));", "me->start_busy(2);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3 + random(2));
      #   - me->start_busy(2 + random(3));
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
      # #define SHEN "「" HIY "金蛇噬天" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         int damage;
      #         string msg, wn;
      #         object weapon;
      #         int ap, dp;
      #         me = this_player();
      # 
      #         if (userp(me) && ! me->query("can_perform/jinshe-jian/shi"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(SHEN "只能在战斗中对对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon"))
      #            || (string)weapon->query("skill_type") != "sword")
      #                 return notify_fail("你使用的武器不对，难以施展" SHEN "。\n");
      # 
      #         if ((int)me->query_skill("jinshe-jian", 1) < 200)
      #                 return notify_fail("你金蛇剑法不够娴熟，难以施展" SHEN "。\n");
      # 
      #         if (me->query_skill_mapped("sword") != "jinshe-jian")
      #                 return notify_fail("你没有激发金蛇剑法，难以施展" SHEN "。\n");
      # 
      #         if ((int)me->query_skill("force", 1) < 240)
      #                 return notify_fail("你的内功火候不够，难以施展" SHEN "。\n");
      # 
      #         if ((int)me->query_skill("dodge", 1) < 240)
      #                 return notify_fail("你的轻功火候不够，难以施展" SHEN "。\n");  
      # 
      #         if ((int)me->query("max_neili") < 4500)
      #                 return notify_fail("你的内力修为不足，难以施展" SHEN "。\n");
      # 
      #         if ((int)me->query("neili") < 400)
      #                 return notify_fail("你现在的真气不够，难以施展" SHEN "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         wn = weapon->name();
      # 
      #         msg = HIY "一道金光划过，$N" HIY "消失得无影无踪，猛然间只见一条"
      #               "金蛇从天而下，" + weapon->name() + HIY "已将$n" HIY "笼罩。\n" NOR;
      # 
      #         message_sort(msg, me, target);
      #         
      #         ap = me->query_skill("jinshe-jian", 1) +
      #              me->query_skill("martial-cognize", 1);
      # 
      #         dp = target->query_skill("dodge", 1) +
      #              target->query_skill("martial-cognize", 1);
      # 
      #         if (ap * 2 / 3 + random(ap) > random(dp))
      #         {
      #                 damage = me->query_skill("jinshe-jian", 1) +
      #                          me->query_skill("force", 1) +
      #                          me->query_skill("martial-cognize", 1);
      # 
      #                 damage += random(damage / 2);
      # 
      #                 // 十分之一的几率可被招架
      #                 if (random(10) <= 1 && ap / 2 < dp)
      #                 {
      #                         damage = damage / 3;
      # 
      #                         msg = COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,
      #                                                   HIG "$n" HIG "见$N" HIG "一道金光闪过"
      #                                                   "，急忙收敛心神奋力招架。哪知$P这"
      #                                                   "招力道非凡，$p一声闷哼，连退几步，喷"
      #                                                   "出一口鲜血。\n" NOR);
      #                         me->add("neili", -200);
      #                         me->start_busy(3 + random(2));
      #                 } else 
      #                 {
      #                         msg = COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 85,
      #                                                   HIR "$n" HIR "见$N" HIR "金光划过，心"
      #                                                   "底不由大惊，登时听得“噗嗤”一声，剑"
      #                                                   "气透体而过。\n" NOR);
      #                         me->add("neili", -300);
      #                         me->start_busy(2 + random(3));
      #                 }
      #         } else
      #         {
      #                 msg = CYN "\n然而$n" CYN "以快对快，飞身一跳"
      #                       "已然躲过$N" CYN "这一招。\n" NOR;
      #                 me->add("neili", -150);
      #                 me->start_busy(2);
      #         }
      #         message_sort(msg, me, target);
      #         return 1;
      # }
end
