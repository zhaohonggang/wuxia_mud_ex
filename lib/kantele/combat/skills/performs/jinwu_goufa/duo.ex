defmodule Kantele.Combat.Skills.Performs.JinwuGoufa.Duo do
  @moduledoc """
  perform「金钩夺魄」（source jinwu-goufa/duo.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "jinwu-goufa"}, {"damage", "force"}, {"dp", "parry"}], "level_gates": [{"jinwu-goufa", "160"}], "map_gates": [{"sword", "jinwu-goufa"}], "prepared_gates": [], "resource_gates": [{"neili", "300"}], "var_gates": [{"damage", "0"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，无法施展", "你没有激发金蜈钩法，无法施展", "你的金蜈钩法还不够娴熟，无法施展", "你现在真气不够，无法施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("jinwu-goufa", 1) +
      #                me->query_skill("sword", 1) / 2", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["CYN", "HIR", "HIY", "NOR", "RED"], "combat_messages": %{"fail": [], "other": ["HIY "突然$N" HIY "一声冷哼，手中" + weapon->name() +
      #                 NOR + HIY "挥出，在空中划出个美丽的弧线，直攻$n" HIY
      #                 "的要穴！\n" NOR", "= COMBAT_D->do_damage(me, target,
      #                                  WEAPON_ATTACK, damage, 40, pmsg)", "= CYN "可是$p" CYN "看破了$P"
      #                          CYN "的企图，避开了这一招。\n"NOR"], "success": ["= HIR "只见$N" HIR "这一击来势好快，寒光一"
      #                                  "闪，正钩中$n" HIR "的咽喉，$n" HIR "一声"
      #                                  "惨叫，软绵绵的瘫了下去。\n" NOR "( $n" RED
      #                                  "受伤过重，已经有如风中残烛，随时都可能断"
      #                                  "气。" NOR ")\n"", "= HIR "只听“嗤啦”一声，$n" HIR "手腕被"
      #                                 "钩个正中，手中" + weapon2->name() + NOR
      #                                 + HIR "再也捉拿不住，脱手而飞！\n" NOR", "HIR "$n" HIR "飞身躲闪，然而只听“嗤啦”"
      #                                  "一声，$N" HIR "的" + weapon->name()+ NOR
      #                                  + HIR "正钩在$n" HIR + limb + "上，顿时鲜"
      #                                  "血狂溅而出。\n" NOR"]}, "damage_formula": %{"formula": "0"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-200"}, {"neili", "-50"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-200"}, {"neili", "-50"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2 + random(2));", "me->start_busy(2 + random(2));", "target->start_busy(2);", "me->start_busy(4);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2 + random(2));
      #   - me->start_busy(2 + random(2));
      #   - target->start_busy(2);
      #   - me->start_busy(4);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define DUO "「" HIY "金钩夺魄" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         object weapon, weapon2;
      #         int damage;
      #         string  msg;
      #         string  pmsg;
      #         string *limbs;
      #         string  limb;
      #         int ap, dp;
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (userp(me) && ! me->query("can_perform/jinwu-goufa/duo"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(DUO "只能对战斗中的对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon")) ||
      #             (string)weapon->query("skill_type") != "sword")
      #                 return notify_fail("你使用的武器不对，无法施展" DUO "。\n");
      # 
      #         if (me->query_skill_mapped("sword") != "jinwu-goufa") 
      #                 return notify_fail("你没有激发金蜈钩法，无法施展" DUO "。\n");
      # 
      #         if ((int)me->query_skill("jinwu-goufa", 1) < 160)
      #                 return notify_fail("你的金蜈钩法还不够娴熟，无法施展" DUO "。\n");
      #                                 
      #         if ((int)me->query("neili", 1) < 300)
      #                 return notify_fail("你现在真气不够，无法施展" DUO "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIY "突然$N" HIY "一声冷哼，手中" + weapon->name() +
      #               NOR + HIY "挥出，在空中划出个美丽的弧线，直攻$n" HIY
      #               "的要穴！\n" NOR;
      #         me->add("neili", -50);
      # 
      #         ap = me->query_skill("jinwu-goufa", 1) +
      #              me->query_skill("sword", 1) / 2;
      #         dp = target->query_skill("parry");
      # 
      #         me->want_kill(target);
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 me->start_busy(2 + random(2));
      #                 me->add("neili", -200);
      #                 damage = 0;
      # 
      #                 if (me->query("max_neili") > target->query("max_neili") * 2)
      #                 {
      #                         msg += HIR "只见$N" HIR "这一击来势好快，寒光一"
      #                                "闪，正钩中$n" HIR "的咽喉，$n" HIR "一声"
      #                                "惨叫，软绵绵的瘫了下去。\n" NOR "( $n" RED
      #                                "受伤过重，已经有如风中残烛，随时都可能断"
      #                                "气。" NOR ")\n";
      #                         damage = -1;
      #                 } else
      #                 if (objectp(weapon2 = target->query_temp("weapon")) &&
      #                 me->query_skill("sword") > target->query_skill("parry"))
      #                 {
      #                         // if(userp(me))
      #                         msg += HIR "只听“嗤啦”一声，$n" HIR "手腕被"
      #                               "钩个正中，手中" + weapon2->name() + NOR
      #                               + HIR "再也捉拿不住，脱手而飞！\n" NOR;
      #                         me->start_busy(2 + random(2));
      #                         target->start_busy(2);
      #                         weapon2->move(environment(target));
      #                 } else
      #                 {
      #                         damage = ap + (int)me->query_skill("force");
      #                         damage = damage / 2 + random(damage / 2);
      #                         
      #                         if (arrayp(limbs = target->query("limbs")))
      #                                 limb = limbs[random(sizeof(limbs))];
      #                         else
      #                                 limb = "要害";
      #                         pmsg = HIR "$n" HIR "飞身躲闪，然而只听“嗤啦”"
      #                                "一声，$N" HIR "的" + weapon->name()+ NOR
      #                                + HIR "正钩在$n" HIR + limb + "上，顿时鲜"
      #                                "血狂溅而出。\n" NOR;
      #                         msg += COMBAT_D->do_damage(me, target,
      #                                WEAPON_ATTACK, damage, 40, pmsg);
      #                 }
      #         } else 
      #         {
      #                 me->start_busy(4);
      #                 msg += CYN "可是$p" CYN "看破了$P"
      #                        CYN "的企图，避开了这一招。\n"NOR;
      #         }
      # 
      #         message_combatd(msg, me, target);
      #         if (damage < 0) target->die(me);
      # 
      #         return 1;
      # }
end
