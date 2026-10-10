defmodule Kantele.Combat.Skills.Performs.JinwuDaofa.Chi do
  @moduledoc """
  perform「赤焰暴长」（source jinwu-daofa/chi.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "blade"}, {"dp", "parry"}], "level_gates": [{"jinwu-daofa", "120"}], "map_gates": [{"blade", "jinwu-daofa"}], "prepared_gates": [], "resource_gates": [{"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，无法施展", "你的金乌刀法不够娴熟，无法施展", "你现在真气不够，无法施展", "你没有激发金乌刀法，无法施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("blade")", "dp_formula": "target->query_skill("parry")"}, "callback_functions": [%{"body": "return  HIR "只听$n" HIR "一声惨叫，被这一刀劈个正中，伤口"
      #                   "深可见骨，鲜血四处飞溅。\n" NOR;", "name": "final", "params": "object me, object target, int damage", "return_type": "string"}], "color_codes": ["HIC", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "$N" HIY "凝神聚气，将全身之力注入" + weapon->name() +
      #                 HIY "刀身顺势劈下，顿时一股凌厉的刀芒直贯$n" HIY "而去。\n"
      #                 NOR", "= HIY "$n" HIY "慌忙中忙以雪山剑法作出抵挡，哪知$N"
      #                          HIY "刀法竟似雪山剑法克星般，" + weapon->name() +
      #                          HIY "焰芒霎时\n又暴涨数倍，完全封锁$n" HIY "的所"
      #                          "有剑招！\n" NOR", "= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 40,
      #                                              (: final, me, target, damage :))", "= HIC "可$n" HIC "却是镇定逾恒，一丝不乱，"
      #                          "全神将此招化解开来。\n" NOR"], "success": []}, "damage_formula": %{"formula": "ap / 2 + random(ap / 2)"}, "do_damage_calls": [%{"attack_type": "WEAPON_ATTACK", "callback": "final", "damage_factor": 40, "damage_var": "damage"}], "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-150"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_forbidden": ["sword"], "weapon_type": "blade"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-150"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
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
      # #define CHI "「" HIY "赤焰暴长" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # string final(object me, object target, int damage);
      # 
      # int perform(object me, object target)
      # {
      #         object weapon, weapon2;
      #         string msg;
      #         int ap, dp;
      #         int damage;
      # 
      #         if (userp(me) && ! me->query("can_perform/jinwu-daofa/chi"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(CHI "只能对战斗中的对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon"))
      #            || (string)weapon->query("skill_type") != "blade")
      #                 return notify_fail("你使用的武器不对，无法施展" CHI "。\n");
      # 
      #         if ((int)me->query_skill("jinwu-daofa", 1) < 120)
      #                 return notify_fail("你的金乌刀法不够娴熟，无法施展" CHI "。\n");
      # 
      #         if (me->query("neili") < 200)
      #                 return notify_fail("你现在真气不够，无法施展" CHI "。\n");
      # 
      #         if (me->query_skill_mapped("blade") != "jinwu-daofa")
      #                 return notify_fail("你没有激发金乌刀法，无法施展" CHI "。\n");
      # 
      #         if (! living(target))
      #                return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIY "$N" HIY "凝神聚气，将全身之力注入" + weapon->name() +
      #               HIY "刀身顺势劈下，顿时一股凌厉的刀芒直贯$n" HIY "而去。\n"
      #               NOR;
      # 
      #         me->add("neili", -150);
      #         ap = me->query_skill("blade");
      #         dp = target->query_skill("parry");
      # 
      #         if (objectp(weapon2 = target->query_temp("weapon"))
      #            && (string)weapon2->query("skill_type") == "sword"
      #            && target->query_skill_mapped("sword") == "xueshan-jian")
      #     {
      #                 msg += HIY "$n" HIY "慌忙中忙以雪山剑法作出抵挡，哪知$N"
      #                        HIY "刀法竟似雪山剑法克星般，" + weapon->name() +
      #                        HIY "焰芒霎时\n又暴涨数倍，完全封锁$n" HIY "的所"
      #                        "有剑招！\n" NOR;
      #         ap += ap / 2;
      #     }
      # 
      #         me->start_busy(3);
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 damage = ap / 2 + random(ap / 2);
      #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 40,
      #                                            (: final, me, target, damage :));
      #         } else
      #         {
      #                 msg += HIC "可$n" HIC "却是镇定逾恒，一丝不乱，"
      #                        "全神将此招化解开来。\n" NOR;
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
      # 
      # string final(object me, object target, int damage)
      # {
      #         return  HIR "只听$n" HIR "一声惨叫，被这一刀劈个正中，伤口"
      #                 "深可见骨，鲜血四处飞溅。\n" NOR;
      # }
end
