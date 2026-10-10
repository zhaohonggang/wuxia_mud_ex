defmodule Kantele.Combat.Skills.Performs.XueshanJian.Chu do
  @moduledoc """
  perform「雪花六出」（source xueshan-jian/chu.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "sword"}, {"dp", "parry"}], "level_gates": [{"force", "200"}, {"xueshan-jian", "140"}], "map_gates": [{"sword", "xueshan-jian"}], "prepared_gates": [], "resource_gates": [{"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你的内功的修为不够，难以施展", "你的雪山剑法修为不够，难以施展", "你的真气不够，难以施展", "你没有激发雪山剑法，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("sword")", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["HIC", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "$N" HIW "手中" + weapon->name() + HIW
      #                 "抖动，正是一招「雪花六出」。虚中有实，实中有"
      #                 "虚，四面八方向$n" HIW "攻去！\n" NOR", "= HIC "$n" HIC "见$N" HIC "剑招汹涌，寒"
      #                          "风袭体，急忙凝神聚气，小心应付。\n"
      #                          NOR"], "success": ["= HIR "$n" HIR "只觉剑影重重，登时眼花缭"
      #                          "乱，被攻了个措手不及，疲于奔命。\n" NOR"]}, "hit_formula": %{"left_side": "ap / 2 + random(ap * 2)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-attack_time * 20"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["me->start_busy(1 + random(attack_time));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1 + random(attack_time));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define CHU "「" HIW "雪花六出" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         object weapon;
      #         string msg;
      #         int ap, dp;
      #         int count;
      #         int i, attack_time;
      # 
      #         if (! target)
      #         {
      #                 me->clean_up_enemy();
      #                 target = me->select_opponent();
      #         }
      # 
      #         if (userp(me) && ! me->query("can_perform/xueshan-jian/chu"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(CHU "只能对战斗中的对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon")) ||
      #               (string)weapon->query("skill_type") != "sword")
      #                 return notify_fail("你使用的武器不对，难以施展" CHU "。\n");
      # 
      #         if (me->query_skill("force") < 200)
      #                 return notify_fail("你的内功的修为不够，难以施展" CHU "。\n");
      # 
      #         if (me->query_skill("xueshan-jian", 1) < 140)
      #                 return notify_fail("你的雪山剑法修为不够，难以施展" CHU "。\n");
      # 
      #         if (me->query("neili") < 200)
      #                 return notify_fail("你的真气不够，难以施展" CHU "。\n");
      # 
      #         if (me->query_skill_mapped("sword") != "xueshan-jian")
      #                 return notify_fail("你没有激发雪山剑法，难以施展" CHU "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIW "$N" HIW "手中" + weapon->name() + HIW
      #               "抖动，正是一招「雪花六出」。虚中有实，实中有"
      #               "虚，四面八方向$n" HIW "攻去！\n" NOR;
      # 
      #         ap = me->query_skill("sword");
      #         dp = target->query_skill("parry");
      #         attack_time = 6;
      # 
      #         if (ap / 2 + random(ap * 2) > dp)
      #         {
      #                 msg += HIR "$n" HIR "只觉剑影重重，登时眼花缭"
      #                        "乱，被攻了个措手不及，疲于奔命。\n" NOR;
      #                 count = ap / 10;
      #                 me->add_temp("apply/attack", count);
      #         } else
      #         {
      #                 msg += HIC "$n" HIC "见$N" HIC "剑招汹涌，寒"
      #                        "风袭体，急忙凝神聚气，小心应付。\n"
      #                        NOR;
      #                 count = 0;
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         me->add("neili", -attack_time * 20);
      # 
      #         for (i = 0; i < attack_time; i++)
      #         {
      #                 if (! me->is_fighting(target))
      #                         break;
      #                 COMBAT_D->do_attack(me, target, weapon, 0);
      #         }
      # 
      #         me->add_temp("apply/attack", -count);
      #         me->start_busy(1 + random(attack_time));
      #         return 1;
      # }
end
