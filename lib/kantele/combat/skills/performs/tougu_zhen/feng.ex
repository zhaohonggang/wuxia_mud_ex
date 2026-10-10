defmodule Kantele.Combat.Skills.Performs.TouguZhen.Feng do
  @moduledoc """
  perform「封杀」（source tougu-zhen/feng.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "finger"}, {"dp", "parry"}, {"lvl", "tougu-zhen"}], "level_gates": [{"force", "260"}, {"tougu-zhen", "100"}], "map_gates": [], "prepared_gates": [{"finger", "tougu-zhen"}], "resource_gates": [{"max_neili", "2400"}, {"neili", "350"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"affect_by_callbacks": [%{"buff_name": "tougu_zhen", "duration_formula": "lvl / 50 + random(lvl / 20)", "id_formula": "me->query("id")", "level_formula": "me->query("jiali") + random(me->query("jiali"))"}], "all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的透骨针还不够娴熟，无法施展", "你内功火候不够，难以施展", "你的真气不够，无法施展", "你的真气不够，无法施展", "你没有准备使用透骨针，无法使用", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("finger") + me->query_skill("force")", "dp_formula": "target->query_skill("parry") + target->query_skill("dodge")"}, "callback_functions": [%{"body": "target->affect_by("tougu_zhen",
      #                           ([ "level"    : me->query("jiali") + random(me->query("jiali")),
      #                              "id"       : me->query("id"),
      #                         ", "name": "final", "params": "object me, object target, int lvl", "return_type": "string"}], "color_codes": ["CYN", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 65,
      #                                              (: final, me, target, lvl :))", "= CYN "可是$n急忙退闪，连消带打躲开了这一击。\n" NOR"], "success": ["HIW "$N" HIW "使出透骨针「" HIR "封 杀" HIW "」绝技，手指挥舞，幻出漫天寒星"
      #                 "，携带着阴寒之劲直封$n" HIW "各处要穴！\n" NOR"]}, "damage_formula": %{"formula": "ap + random(ap / 2)"}, "do_damage_calls": [%{"attack_type": "UNARMED_ATTACK", "callback": "final", "damage_factor": 65, "damage_var": "damage"}], "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-280"}, {"neili", "-50"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-280"}, {"neili", "-50"}], "affect_by": ["tougu_zhen"], "apply_adds": [], "busy_lines": ["me->start_busy(1);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
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
      # #define SHA "「" HIR "封杀" NOR "」"
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
      #         if (userp(me) && ! me->query("can_perform/tougu-zhen/feng"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(SHA "只能在战斗中使用。\n");
      # 
      #         if ((int)me->query_skill("tougu-zhen", 1) < 100)
      #                 return notify_fail("你的透骨针还不够娴熟，无法施展" SHA "！\n");
      # 
      #         if ((int)me->query_skill("force") < 260)
      #                 return notify_fail("你内功火候不够，难以施展" SHA "！\n");
      # 
      #         if ((int)me->query("max_neili") < 2400)
      #                 return notify_fail("你的真气不够，无法施展" SHA "！\n");
      # 
      #         if ((int)me->query("neili") < 350)
      #                 return notify_fail("你的真气不够，无法施展" SHA "！\n");
      # 
      #         if (me->query_skill_prepared("finger") != "tougu-zhen") 
      #                 return notify_fail("你没有准备使用透骨针，无法使用" SHA "！\n");
      # 
      #        if (! living(target))
      #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIW "$N" HIW "使出透骨针「" HIR "封 杀" HIW "」绝技，手指挥舞，幻出漫天寒星"
      #               "，携带着阴寒之劲直封$n" HIW "各处要穴！\n" NOR;
      # 
      #         lvl = me->query_skill("tougu-zhen", 1);
      # 
      #         ap = me->query_skill("finger") + me->query_skill("force");
      #         dp = target->query_skill("parry") + target->query_skill("dodge");
      # 
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 damage = ap + random(ap / 2);
      # 
      #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 65,
      #                                            (: final, me, target, lvl :));
      #                
      #                 me->add("neili", -280);
      #                 me->start_busy(1);
      #         } else
      #         {
      #                 msg += CYN "可是$n急忙退闪，连消带打躲开了这一击。\n" NOR;
      #                 me->start_busy(3);
      #                 me->add("neili", -50);
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
      # 
      # string final(object me, object target, int lvl)
      # {
      #        target->affect_by("tougu_zhen",
      #                         ([ "level"    : me->query("jiali") + random(me->query("jiali")),
      #                            "id"       : me->query("id"),
      #                            "duration" : lvl / 50 + random(lvl / 20) ]));
      # 
      #         return HIR "结果只听$n一声惨嚎，被攻个正着，透骨针极寒之劲攻心，全身瘫麻，鲜血狂喷！\n" NOR;
      # }
end
