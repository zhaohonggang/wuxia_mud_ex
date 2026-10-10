defmodule Kantele.Combat.Skills.Performs.YinfengDao.Jue do
  @moduledoc """
  perform「绝杀」（source yinfeng-dao/jue.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "strike"}, {"dp", "parry"}, {"lvl", "yinfeng-dao"}], "level_gates": [{"force", "260"}, {"yinfeng-dao", "140"}], "map_gates": [{"strike", "yinfeng-dao"}], "prepared_gates": [], "resource_gates": [{"max_neili", "2400"}, {"neili", "400"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"affect_by_callbacks": [%{"buff_name": "yinfeng_dao", "duration_formula": "lvl / 50 + random(lvl / 20)", "id_formula": "me->query("id")", "level_formula": "me->query("jiali") + random(me->query("jiali"))"}], "all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的阴风刀还不够娴熟，无法施展", "你内功火候不够，难以施展", "你的真气不够，无法施展", "你的真气不够，无法施展", "你没有激发阴风刀，无法使用", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("strike") + me->query_skill("force")", "dp_formula": "target->query_skill("parry") + target->query_skill("dodge")"}, "callback_functions": [%{"body": "target->affect_by("yinfeng_dao",
      #                          ([ "level"    : me->query("jiali") + random(me->query("jiali")),
      #                             "id"       : me->query("id"),
      #                          ", "name": "final", "params": "object me, object target, int lvl", "return_type": "string"}], "color_codes": ["CYN", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 70,
      #                                              (: final, me, target, lvl :))", "= CYN "可是$n急忙退闪，连消带打躲开了这一击。\n" NOR"], "success": ["HIW "$N" HIW "使出阴风刀「" HIR "绝 杀" HIW"」绝技，掌劲幻出一片片切骨寒"
      #                 "气如飓风般裹向$n全身！\n" NOR"]}, "damage_formula": %{"formula": "ap + random(ap / 2)"}, "do_damage_calls": [%{"attack_type": "UNARMED_ATTACK", "callback": "final", "damage_factor": 70, "damage_var": "damage"}], "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-150"}, {"neili", "-350"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-150"}, {"neili", "-350"}], "affect_by": ["yinfeng_dao"], "apply_adds": [], "busy_lines": ["me->start_busy(1);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1);
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
      # inherit F_SSERVER;
      # 
      # #define SHA "「" HIR "绝杀" NOR "」"
      # 
      # string final(object me, object targer, int lvl);
      # 
      # int perform(object me, object target)
      # {
      #         string msg;
      #         int ap, dp;
      #         int damage;
      #         int lvl;
      # 
      #         if (userp(me) && ! me->query("can_perform/yinfeng-dao/jue"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(SHA "只能在战斗中使用。\n");
      # 
      #         if ((int)me->query_skill("yinfeng-dao", 1) < 140)
      #                 return notify_fail("你的阴风刀还不够娴熟，无法施展" SHA "绝技！\n");
      # 
      #         if ((int)me->query_skill("force") < 260)
      #                 return notify_fail("你内功火候不够，难以施展" SHA "绝技！\n");
      # 
      #         if ((int)me->query("max_neili") < 2400)
      #                 return notify_fail("你的真气不够，无法施展" SHA "绝技！！\n");
      # 
      #         if ((int)me->query("neili") < 400)
      #                 return notify_fail("你的真气不够，无法施展" SHA "绝技！！\n");
      # 
      #         if (me->query_skill_mapped("strike") != "yinfeng-dao") 
      #                 return notify_fail("你没有激发阴风刀，无法使用" SHA "绝技！\n");
      # 
      #        if (! living(target))
      #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIW "$N" HIW "使出阴风刀「" HIR "绝 杀" HIW"」绝技，掌劲幻出一片片切骨寒"
      #               "气如飓风般裹向$n全身！\n" NOR;
      #  
      #         lvl = me->query_skill("yinfeng-dao", 1);
      # 
      #         ap = me->query_skill("strike") + me->query_skill("force");
      #         dp = target->query_skill("parry") + target->query_skill("dodge");
      # 
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 damage = ap + random(ap / 2);
      # 
      #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 70,
      #                                            (: final, me, target, lvl :));
      #               
      #                 me->add("neili", -350);
      #                 me->start_busy(1);
      #         } else
      #         {
      #                 msg += CYN "可是$n急忙退闪，连消带打躲开了这一击。\n" NOR;
      #                 me->start_busy(3);
      #                 me->add("neili", -150);
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
      # 
      # string final(object me, object target, int lvl)
      # {
      #        target->affect_by("yinfeng_dao",
      #                        ([ "level"    : me->query("jiali") + random(me->query("jiali")),
      #                           "id"       : me->query("id"),
      #                           "duration" : lvl / 50 + random(lvl / 20) ]));
      # 
      #        return HIR "结果只听$n一声惨嚎，全身几处要穴同时被阴风寒劲砍中，疼若刮骨，鲜血狂泄而出！\n" NOR;
      # }
end
