defmodule Kantele.Combat.Skills.Performs.TaijiJian.Zhenwu do
  @moduledoc """
  perform「真武除邪」（source taiji-jian/zhenwu.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "sword"}, {"dp", "parry"}], "level_gates": [{"taiji-jian", "180"}], "map_gates": [{"sword", "taiji-jian"}], "prepared_gates": [], "resource_gates": [{"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你的太极剑法不够娴熟，难以施展", "你现在真气不够，难以施展", "你没有激发太极剑法，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("sword")", "dp_formula": "target->query_skill("parry")"}, "callback_functions": [%{"body": "target->receive_damage("jing", damage / 4, me);
      #           target->receive_wound("jing", damage / 8, me);
      #           return  HIY "结果$n" HIY "却丝毫未把这招放在眼里，随手应了一招，却见$N"
      #                   HIY "剑势\n忽然一变，气象万千，变幻无穷，", "name": "final", "params": "object me, object target, int damage", "return_type": "string"}], "color_codes": ["HIC", "HIR", "HIY", "NOR"], "combat_exp_formulas": [{"lvl", "to_int(pow(to_float(me->query("combat_exp") * 10), 1.0 / 3))"}], "combat_messages": %{"fail": [], "other": ["HIY "$N" HIY "跨前一步，平平挥出一剑，横扫$n" HIY "而去，毫"
      #                 "无半点花巧可言。\n" NOR", "= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 85,
      #                                              (: final, me, target, damage :))", "= HIC "可是$n" HIC "看透$P" HIC "招后更有杀着，镇"
      #                          "定逾恒，全神应对自如。\n" NOR"], "success": []}, "damage_formula": %{"formula": "ap + random(ap / 3)"}, "do_damage_calls": [%{"attack_type": "WEAPON_ATTACK", "callback": "final", "damage_factor": 85, "damage_var": "damage"}], "hit_formula": %{"left_side": "ap * 3 / 5 + random(ap)", "operator": ">", "right_side": "dp"}, "receive_damage_calls": [%{"formula": "damage / 4", "kind": "damage", "part": "jing", "source": "me"}, %{"formula": "damage / 8", "kind": "wound", "part": "jing", "source": "me"}], "resource_adds": [{"neili", "-50"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-50"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);"], "remote_damage": true, "set_flags": [], "temp_set": []}
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
      # #define ZHENWU "「" HIY "真武除邪" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # string final(object me, object target, int damage);
      # 
      # int perform(object me, object target)
      # {
      #         object weapon;
      #         string msg;
      #         int ap, dp;
      #         int damage;
      # 
      #         float improve;
      #         int lvl, m, n;
      #         string martial;
      #         string *ks;
      #         martial = "sword";
      # 
      #         if (userp(me) && ! me->query("can_perform/taiji-jian/zhenwu"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(ZHENWU "只能对战斗中的对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon")) ||
      #             (string)weapon->query("skill_type") != "sword")
      #                 return notify_fail("你使用的武器不对，难以施展" ZHENWU "。\n");
      # 
      #         if ((int)me->query_skill("taiji-jian", 1) < 180)
      #                 return notify_fail("你的太极剑法不够娴熟，难以施展" ZHENWU "。\n");
      # 
      #         if (me->query("neili") < 200)
      #                 return notify_fail("你现在真气不够，难以施展" ZHENWU "。\n");
      # 
      #         if (me->query_skill_mapped("sword") != "taiji-jian")
      #                 return notify_fail("你没有激发太极剑法，难以施展" ZHENWU "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIY "$N" HIY "跨前一步，平平挥出一剑，横扫$n" HIY "而去，毫"
      #               "无半点花巧可言。\n" NOR;
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
      #         improve = improve * 5 / 100 / lvl;
      # 
      #         me->add("neili", -50);
      #         ap = me->query_skill("sword");
      #         dp = target->query_skill("parry");
      #         ap += ap * improve;
      #         if (target->is_bad()) ap += ap / 8;
      # 
      #         me->start_busy(2);
      #         if (ap * 3 / 5 + random(ap) > dp)
      #         {
      #                 damage = ap + random(ap / 3);
      #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 85,
      #                                            (: final, me, target, damage :));
      #         } else
      #         {
      #                 msg += HIC "可是$n" HIC "看透$P" HIC "招后更有杀着，镇"
      #                        "定逾恒，全神应对自如。\n" NOR;
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
      # 
      # string final(object me, object target, int damage)
      # {
      #         target->receive_damage("jing", damage / 4, me);
      #         target->receive_wound("jing", damage / 8, me);
      #         return  HIY "结果$n" HIY "却丝毫未把这招放在眼里，随手应了一招，却见$N"
      #                 HIY "剑势\n忽然一变，气象万千，变幻无穷，极具王者风范！\n" NOR +
      #                 HIR "$n" HIR "顿时惊慌失措，被$P" HIR "这一剑击中要害，鲜血崩流"
      #                 "，惨不忍睹！\n" NOR;
      # }
end
