defmodule Kantele.Combat.Skills.Performs.YuanshiJian.Xuan do
  @moduledoc """
  perform「天旋地转」（source yuanshi-jian/xuan.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "sword"}, {"dp", "force"}], "level_gates": [{"yuanshi-jian", "180"}], "map_gates": [{"sword", "yuanshi-jian"}], "prepared_gates": [], "resource_gates": [{"neili", "400"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你的原始剑法不够娴熟，难以施展", "你的真气不够，难以施展", "你没有激发原始剑法，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("sword")", "dp_formula": "target->query_skill("force")"}, "color_codes": ["HIC", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "$N" HIW "一振手中" + weapon->name() + HIW "，挽出数朵剑花，层"
      #                 "层涌向$n" HIW"，犹如潮水，一浪高过一浪。\n" NOR", "= HIC "$n" HIC "见$N" HIC "剑势汹涌，急忙凝神抵挡"
      #                          "，不为所困。\n" NOR"], "success": ["= HIR "$n" HIR "顿时只觉得头晕目眩，天旋地转，一时"
      #                          "难以招架。\n" NOR"]}, "hit_formula": %{"left_side": "ap / 2 + random(ap * 2)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-attack_time * 30"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
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
      # #define XUAN "「" HIW "天旋地转" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #     object weapon;
      #     string msg;
      #     int ap, dp;
      #         int count;
      #     int i, attack_time;
      # 
      #         if (userp(me) && ! me->query("can_perform/yuanshi-jian/xuan"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #     if (! target) target = offensive_target(me);
      # 
      #     if (! target || ! me->is_fighting(target))
      #                 return notify_fail(XUAN "只能对战斗中的对手使用。\n");
      # 
      #     if (! objectp(weapon = me->query_temp("weapon")) ||
      #             (string)weapon->query("skill_type") != "sword")
      #                 return notify_fail("你使用的武器不对，难以施展" XUAN "。\n");
      # 
      #     if ((int)me->query_skill("yuanshi-jian", 1) < 180)
      #         return notify_fail("你的原始剑法不够娴熟，难以施展" XUAN "。\n");
      # 
      #     if (me->query("neili") < 400)
      #         return notify_fail("你的真气不够，难以施展" XUAN "。\n");
      # 
      #         if (me->query_skill_mapped("sword") != "yuanshi-jian")
      #                 return notify_fail("你没有激发原始剑法，难以施展" XUAN "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #     msg = HIW "$N" HIW "一振手中" + weapon->name() + HIW "，挽出数朵剑花，层"
      #               "层涌向$n" HIW"，犹如潮水，一浪高过一浪。\n" NOR;
      # 
      #     ap = me->query_skill("sword");
      #     dp = target->query_skill("force");
      #         attack_time = 5;
      #     if (ap / 2 + random(ap * 2) > dp)
      #     {
      #         msg += HIR "$n" HIR "顿时只觉得头晕目眩，天旋地转，一时"
      #                        "难以招架。\n" NOR;
      #                 count = ap / 16;
      #                 me->add_temp("apply/attack", count);
      #                 attack_time += random(ap / 45);
      #         } else
      #         {
      #                 msg += HIC "$n" HIC "见$N" HIC "剑势汹涌，急忙凝神抵挡"
      #                        "，不为所困。\n" NOR;
      #                 count = 0;
      #         }
      # 
      #     message_combatd(msg, me, target);
      # 
      #         if (attack_time > 7)
      #                 attack_time = 7;
      # 
      #     me->add("neili", -attack_time * 30);
      # 
      #     for (i = 0; i < attack_time; i++)
      #     {
      #         if (! me->is_fighting(target))
      #             break;
      #         COMBAT_D->do_attack(me, target, weapon, 0);
      #     }
      # 
      #         me->add_temp("apply/attack", -count);
      #     me->start_busy(1 + random(attack_time));
      # 
      #     return 1;
      # }
end
