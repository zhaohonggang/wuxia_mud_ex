defmodule Kantele.Combat.Skills.Performs.LingsheZhangfa.Wanshi do
  @moduledoc """
  perform「wanshi」（source lingshe-zhangfa/wanshi.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "staff"}, {"dp", "parry"}], "level_gates": [{"lingshe-zhangfa", "160"}], "map_gates": [{"staff", "lingshe-zhangfa"}], "prepared_gates": [], "resource_gates": [{"neili", "400"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你还不会使用「千蛇万噬」这一绝技。\n", "「千蛇万噬」只能对战斗中的对手使用。\n", "你使用的武器不对。\n", "你的灵蛇杖法不够娴熟，不会使用「千蛇万噬」。\n", "你现在真气不够，无法使用「千蛇万噬」。\n", "你没有激发灵蛇杖法，无法使用「千蛇万噬」！\n", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("staff")", "dp_formula": "target->query_skill("parry")"}, "callback_functions": [%{"body": "target->receive_damage("jing", damage / 4, me);
      #           target->receive_wound("jing", damage / 8, me);
      #           return HIW "哪知" HIW + weapon->name() + HIW "突然拐弯，绕到$p" HIW "背后，"
      #                   "重重地击在了$", "name": "final", "params": "object me, object target, int damage, object weapon", "return_type": "string"}], "color_codes": ["HIB", "HIG", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIB "$N" HIB "手持" + weapon->name() + HIB "，直捣$n中宫" HIB "。\n" NOR", "= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,
      #                                              (: final, me, target, damage, weapon :))", "= HIG "可是$p" HIG "看破了$P" HIG "的企图，一"
      #                          "缩胸，急退三步，避开了这一招。\n" NOR"], "success": []}, "damage_formula": %{"formula": "ap + random(ap / 4)"}, "do_damage_calls": [%{"attack_type": "WEAPON_ATTACK", "callback": "final", "damage_factor": 50, "damage_var": "damage"}], "hit_formula": %{"left_side": "ap / 3 + random(ap)", "operator": ">", "right_side": "dp"}, "receive_damage_calls": [%{"formula": "damage / 4", "kind": "damage", "part": "jing", "source": "me"}, %{"formula": "damage / 8", "kind": "wound", "part": "jing", "source": "me"}], "resource_adds": [{"neili", "-100"}, {"neili", "-350"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "staff"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-350"}, {"poison_applied", "-1"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2 + random(4));"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2 + random(4));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // wanshi.c 灵蛇杖法「千蛇万噬」
      # // by jeeny
      # 
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # //#define LINGSHE_ZHANG    "/clone/weapon/lingshe"
      # #define LINGSHE_ZHANG    "d/baituo/obj/lingshezhang"
      # 
      # inherit F_SSERVER;
      # 
      # string final(object me, object target, int damage, object weapon);
      # 
      # int perform(object me, object target)
      # {
      #         object weapon;
      #         string msg;
      #         int ap, dp;
      #         int damage;
      #         
      #         if (! target) target = offensive_target(me);
      # 
      #         if (userp(me) && ! me->query("can_perform/lingshe-zhangfa/wanshi"))
      #                 return notify_fail("你还不会使用「千蛇万噬」这一绝技。\n");
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail("「千蛇万噬」只能对战斗中的对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon")) ||
      #             (string)weapon->query("skill_type") != "staff")
      #                 return notify_fail("你使用的武器不对。\n");
      # 
      # 
      #         if ((int)me->query_skill("lingshe-zhangfa", 1) < 160)
      #                 return notify_fail("你的灵蛇杖法不够娴熟，不会使用「千蛇万噬」。\n");
      # 
      #         if (me->query("neili") < 400)
      #                 return notify_fail("你现在真气不够，无法使用「千蛇万噬」。\n");
      # 
      #         if (me->query_skill_mapped("staff") != "lingshe-zhangfa") 
      #                 return notify_fail("你没有激发灵蛇杖法，无法使用「千蛇万噬」！\n");
      # 
      #         if (! living(target))
      #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIB "$N" HIB "手持" + weapon->name() + HIB "，直捣$n中宫" HIB "。\n" NOR;
      # 
      #         ap = me->query_skill("staff");
      #         dp = target->query_skill("parry");
      #         
      #         if (target->is_good()) ap += ap / 10;
      # 
      #         me->start_busy(2 + random(4));
      #         if (ap / 3 + random(ap) > dp)
      #         {
      #                 damage = ap + random(ap / 4);
      #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,
      #                                            (: final, me, target, damage, weapon :));
      #                 me->add("neili", -350);
      #                 if (LINGSHE_ZHANG->query("poison_applied") > 0 && weapon == find_object("/d/baituo/obj/lingshezhang"))
      #                 {
      #                         target->apply_condition("snake_poison", ap / 2, me);
      #                         LINGSHE_ZHANG->add("poison_applied", -1);
      #                 }
      #         } else
      #         {
      #                 msg += HIG "可是$p" HIG "看破了$P" HIG "的企图，一"
      #                        "缩胸，急退三步，避开了这一招。\n" NOR;
      #                 me->add("neili", -100);
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
      # 
      # string final(object me, object target, int damage, object weapon)
      # {
      #         target->receive_damage("jing", damage / 4, me);
      #         target->receive_wound("jing", damage / 8, me);
      #         return HIW "哪知" HIW + weapon->name() + HIW "突然拐弯，绕到$p" HIW "背后，"
      #                 "重重地击在了$p" HIW "的颈脖子上！\n"
      #                 HIB "$p" HIB "“噗”地吐出一口鲜血，随"
      #                 HIB "即只觉脖颈一阵麻痒。\n" NOR;
      # }
end
