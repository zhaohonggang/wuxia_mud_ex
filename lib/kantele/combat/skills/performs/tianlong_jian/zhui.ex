defmodule Kantele.Combat.Skills.Performs.TianlongJian.Zhui do
  @moduledoc """
  perform「毒龙双锥」（source tianlong-jian/zhui.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "sword"}, {"dp", "parry"}], "level_gates": [{"force", "150"}, {"tianlong-jian", "120"}], "map_gates": [{"sword", "tianlong-jian"}], "prepared_gates": [], "resource_gates": [{"max_neili", "1500"}, {"neili", "500"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你的天龙剑法火候太浅，难以施展", "你的内功修为太浅，难以施展", "你的内力修为太浅，难以施展", "你没有激发天龙剑法，难以施展", "你现在的真气不足，，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("sword")", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["CYN", "HIM", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["HIM "$N" HIM "一声清啸，手中" + weapon->name() + HIM "急速旋转，剑尖"
      #                 "作锥，剑身顿时腾起一股旋风，向$n" HIM "钻去。\n" NOR", "= CYN "可是$n" CYN "奋力格挡，终于架开了$N"
      #                          CYN "的这一剑。\n" NOR", "= HIM "\n$N" HIM "随即抽剑回转，撩下劈上，手中" + weapon->name() + HIM
      #                  "剑尖一颤，又激荡出一股旋涡劲钻向$n" HIM "。\n" NOR", "= CYN "可是$n" CYN "凝神聚气，飞身一跃而起，避开了$N"
      #                          CYN "的杀着。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 30,
      #                                              HIR "$n" HIR "招架不住，哧地一声，$N"
      #                                              HIR "手中的" + weapon->name() + HIR
      #                                              "顿时破体钻入，鲜血四溅！\n" NOR)", "= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 40,
      #                                              HIR "$n" HIR "急忙抽身后退，可只见$N"
      #                                              HIR + weapon->name() + HIR "剑芒一漾"
      #                                              "，胸口便喷出一股血柱！\n" NOR)"]}, "damage_formula": %{"formula": "ap / 3 + random(ap / 2)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-350"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-350"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2 + random(3));"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2 + random(3));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define ZHUI "「" HIM "毒龙双锥" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         object weapon;
      #         string msg;
      #         int ap, dp, damage;
      #         // object ob;
      # 
      #         if (userp(me) && ! me->query("can_perform/tianlong-jian/zhui"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target)
      #         {
      #                 me->clean_up_enemy();
      #                 target = me->select_opponent();
      #         }
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(ZHUI "只能对战斗中的对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon")) ||
      #             (string)weapon->query("skill_type") != "sword")
      #                 return notify_fail("你使用的武器不对，难以施展" ZHUI "。\n");
      # 
      #         if ((int)me->query_skill("tianlong-jian", 1) < 120)
      #                 return notify_fail("你的天龙剑法火候太浅，难以施展" ZHUI "。\n");
      # 
      #         if ((int)me->query_skill("force") < 150)
      #                 return notify_fail("你的内功修为太浅，难以施展" ZHUI "。\n");
      # 
      #         if ((int)me->query("max_neili") < 1500)
      #                 return notify_fail("你的内力修为太浅，难以施展" ZHUI "。\n");
      # 
      #         if (me->query_skill_mapped("sword") != "tianlong-jian")
      #                 return notify_fail("你没有激发天龙剑法，难以施展" ZHUI "。\n");
      # 
      #         if ((int)me->query("neili", 1) < 500)
      #                 return notify_fail("你现在的真气不足，，难以施展" ZHUI "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         ap = me->query_skill("sword");
      #         dp = target->query_skill("parry");
      # 
      #     damage = ap / 3 + random(ap / 2);
      # 
      #         msg = HIM "$N" HIM "一声清啸，手中" + weapon->name() + HIM "急速旋转，剑尖"
      #               "作锥，剑身顿时腾起一股旋风，向$n" HIM "钻去。\n" NOR;
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 30,
      #                                            HIR "$n" HIR "招架不住，哧地一声，$N"
      #                                            HIR "手中的" + weapon->name() + HIR
      #                                            "顿时破体钻入，鲜血四溅！\n" NOR);
      #         } else
      #         {
      #                 msg += CYN "可是$n" CYN "奋力格挡，终于架开了$N"
      #                        CYN "的这一剑。\n" NOR;
      #         }
      # 
      #         msg += HIM "\n$N" HIM "随即抽剑回转，撩下劈上，手中" + weapon->name() + HIM
      #                "剑尖一颤，又激荡出一股旋涡劲钻向$n" HIM "。\n" NOR;
      #         if (ap * 2 / 5 + random(ap) > dp)
      #         {
      #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 40,
      #                                            HIR "$n" HIR "急忙抽身后退，可只见$N"
      #                                            HIR + weapon->name() + HIR "剑芒一漾"
      #                                            "，胸口便喷出一股血柱！\n" NOR);
      #         } else
      #         {
      #             msg += CYN "可是$n" CYN "凝神聚气，飞身一跃而起，避开了$N"
      #                        CYN "的杀着。\n" NOR;
      #     }
      #         me->start_busy(2 + random(3));
      #         me->add("neili", -350);
      #         message_combatd(msg, me, target);
      #         return 1;
      # }
end
