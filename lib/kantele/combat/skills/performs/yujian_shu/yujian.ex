defmodule Kantele.Combat.Skills.Performs.YujianShu.Yujian do
  @moduledoc """
  perform「yujian」（source yujian-shu/yujian.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"damage", "sword"}], "level_gates": [{"force", "400"}, {"sword", "400"}], "map_gates": [], "prepared_gates": [], "resource_gates": [{"max_neili", "5000"}, {"neili", "150"}, {"neili", "1500"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["御剑飞升只能对战斗中的对手使用。\n", "你使用的武器不对。\n", "你的剑法尚达不到「御剑飞升」的境界。\n", "你的内功火候尚达不到「御剑飞升」的境界。\n", "你的内力修为太弱，无法灵活的御驾内力。\n", "你现在内力不够。\n"], "buff_delete": ["jueji/sword/feisheng"], "callback_functions": [%{"body": "object weapon;
      #           int damage;
      #           string msg;
      #   
      #           if (! target) target = offensive_target(me);
      #   
      #           if (! target || ! me->is_fighting(target))
      #           {
      #                   write(HIW "你运", "name": "perform2", "params": "object me, object target", "return_type": "int"}, %{"body": "if (! me) return;
      #           if (! me->query_temp("jueji/sword/feisheng")) return;
      #           me->delete_temp("jueji/sword/feisheng");
      #           tell_object(me, HIW "\n你经过调气养息，又可以继续使用「"
      #                         ", "name": "end_perform2", "params": "object me", "return_type": "void"}], "color_codes": ["CYN", "HIR", "HIW", "NOR", "WHT"], "combat_messages": %{"fail": [], "other": ["HIW "\n$N" HIW "一声巨喝，聚气入腕，只听破空声一响，手中"
      #                + weapon->name() + HIW "携着隐隐风雷之劲向$n" HIW "澎湃贯"
      #                 "\n出，疾若电闪，势如雷霆。\n" NOR", "= CYN "可是$p" CYN "看破了$P" CYN "的企图，斜跃避开。\n" NOR", "HIW "\n$N" HIW "手中御剑凌驾如飞，宛若游龙，灵转千变，一道道"
      #                     "凌厉剑气疾射而出。\n" NOR", "= CYN "可是$p" CYN "看破了$P" CYN "的企图，斜跃避开。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 20,
      #                                              HIR "$n" HIR "看到$N" HIR "这气拔千钧的一击，竟不"
      #                                              "知如何招架，登时受了重创！\n" NOR)", "= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 20,
      #                                              HIR "只听「嗤啦」一声，" HIW "无形剑气" NOR +
      #                                              HIR "竟在$n" HIR "上身刺出一个血洞，数股血柱"
      #                                              "疾射而出！\n" NOR)"]}, "damage_formula": %{"formula": "(int)me->query_skill("sword", 1) +
      #                    (int)me->query_skill("force", 1) +
      #                    (int)me->query_skill("parry", 1) +
      #                    (int)me->query_skill("martial-cognize", 1) / 2"}, "resource_adds": [{"neili", "-100"}, {"neili", "-1000"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": false, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-1000"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2 + random(4));"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2 + random(4));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         object weapon;
      #         int damage;
      #         string msg;
      # 
      #         me->clean_up_enemy();
      #         if (! target) target = me->select_opponent();
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail("御剑飞升只能对战斗中的对手使用。\n");
      # 
      #         if( me->query_temp("jueji/sword/feisheng") )
      #                 return notify_fail( WHT "你无法连续使用「御剑飞升」绝技！\n" NOR );
      # 
      #         if (! objectp(weapon = me->query_temp("weapon")) ||
      #             (string)weapon->query("skill_type") != "sword")
      #                 return notify_fail("你使用的武器不对。\n");
      # 
      #         if ((int)me->query_skill("sword", 1) < 400)
      #                 return notify_fail("你的剑法尚达不到「御剑飞升」的境界。\n");
      # 
      #         if ((int)me->query_skill("force") < 400)
      #                 return notify_fail("你的内功火候尚达不到「御剑飞升」的境界。\n");
      # 
      #         if ((int)me->query("max_neili") < 5000)
      #                 return notify_fail("你的内力修为太弱，无法灵活的御驾内力。\n");
      # 
      #         if ((int)me->query("neili") < 1500)
      #                 return notify_fail("你现在内力不够。\n");
      # 
      #         msg = HIW "\n$N" HIW "一声巨喝，聚气入腕，只听破空声一响，手中"
      #              + weapon->name() + HIW "携着隐隐风雷之劲向$n" HIW "澎湃贯"
      #               "\n出，疾若电闪，势如雷霆。\n" NOR;
      # 
      #         damage = (int)me->query_skill("sword", 1) +
      #                  (int)me->query_skill("force", 1) +
      #                  (int)me->query_skill("parry", 1) +
      #                  (int)me->query_skill("martial-cognize", 1) / 2;
      # 
      #         damage = damage / 4 + random(damage / 4);
      # 
      #         me->start_busy(2 + random(4));
      #         me->set_temp("jueji/sword/feisheng", 1);
      #         call_out("end_perform2", 600, me, weapon, damage); 
      # 
      #         if (random(me->query_skill("force")) > target->query_skill("force") * 3 / 5)
      #         {
      #                 me->add("neili", -1000);
      #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 20,
      #                                            HIR "$n" HIR "看到$N" HIR "这气拔千钧的一击，竟不"
      #                                            "知如何招架，登时受了重创！\n" NOR);
      #                 message_vision(msg, me, target);
      #                 remove_call_out("perform2");
      #                 call_out("perform2", 2, me);
      #                 return 1;
      #         } else
      #         {
      #                 msg += CYN "可是$p" CYN "看破了$P" CYN "的企图，斜跃避开。\n" NOR;
      #                 message_vision(msg, me, target);
      #                 me->add("neili", -100);
      #                 remove_call_out("perform2");
      #                 call_out("perform2", 2, me, target);
      #                 return 1;
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
      # 
      # int perform2(object me, object target)
      # {
      #         object weapon;
      #         int damage;
      #         string msg;
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #         {
      #                 write(HIW "你运转内力，仰天一声清啸，剑在空中盘旋了一圈，又"
      #                       "飞回了你的手中。\n" NOR);
      #                 call_out("end_perform2", 1, me, weapon, damage); 
      #                 return 1;
      #         }
      # 
      #         if (! objectp(weapon = me->query_temp("weapon")) ||
      #             (string)weapon->query("skill_type") != "sword")
      #         {
      #                 write(HIW "你停止使用「御剑飞升」绝技。\n" NOR);
      #                 call_out("end_perform2", 30, me, weapon, damage); 
      #                 return 1;
      #         }
      # 
      #         if ((int)me->query("neili") < 150)
      #         {
      #                 write(HIW "你剑至中途，可怎奈内息不足，只好停止御剑。\n" NOR);
      #                 call_out("end_perform2", 30, me, weapon, damage); 
      #                 return 1;
      #         }
      # 
      #         msg = HIW "\n$N" HIW "手中御剑凌驾如飞，宛若游龙，灵转千变，一道道"
      #                   "凌厉剑气疾射而出。\n" NOR;
      # 
      #         if (random(me->query_skill("force")) > target->query_skill("force") / 2)
      #         {
      #                 damage = (int)me->query_skill("sword", 1) +
      #                          (int)me->query_skill("force", 1) +
      #                          (int)me->query_skill("parry", 1) +
      #                          (int)me->query_skill("martial-cognize", 1) / 2;
      # 
      #                 damage = damage / 5 + random(damage / 5);
      # 
      #                 me->add("neili", -100);
      #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 20,
      #                                            HIR "只听「嗤啦」一声，" HIW "无形剑气" NOR +
      #                                            HIR "竟在$n" HIR "上身刺出一个血洞，数股血柱"
      #                                            "疾射而出！\n" NOR);
      #                 message_vision(msg, me, target);
      #                 remove_call_out("perform2");
      #                 call_out("perform2", 4, me);
      #                 return 1;
      #         } else
      #         {
      #                 msg += CYN "可是$p" CYN "看破了$P" CYN "的企图，斜跃避开。\n" NOR;
      #                 message_vision(msg, me, target);
      #                 me->add("neili", -100);
      #                 remove_call_out("perform2");
      #                 call_out("perform2", 4, me);
      #                 return 1;
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
      # 
      # void end_perform2(object me)
      # {
      #         if (! me) return;
      #         if (! me->query_temp("jueji/sword/feisheng")) return;
      #         me->delete_temp("jueji/sword/feisheng");
      #         tell_object(me, HIW "\n你经过调气养息，又可以继续使用「"
      #                         "御剑飞升」了。\n" NOR); 
      # }
end
