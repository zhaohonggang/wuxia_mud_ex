defmodule Kantele.Combat.Skills.Performs.Shenzhaojing.Ying do
  @moduledoc """
  perform「无影神拳」（source shenzhaojing/ying.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "force"}, {"dp", "force"}, {"lvl", "shenzhaojing"}], "level_gates": [{"shenzhaojing", "200"}, {"unarmed", "200"}], "map_gates": [{"unarmed", "shenzhaojing"}], "prepared_gates": [{"unarmed", "shenzhaojing"}], "resource_gates": [{"max_neili", "5000"}, {"neili", "500"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"affect_by_callbacks": [%{"buff_name": "shenzhao", "duration_formula": "lvl / 50 + random(lvl / 20)", "id_formula": "me->query("id")", "level_formula": "me->query("jiali") + random(me->query("jiali"))"}], "all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你必须空手才能施展", "你没有激发神照经神功为拳脚，无法施展", "你现在没有准备使用神照经神功，无法施展", "你的神照经神功火候不够，无法施展", "你的基本拳脚火候不够，无法施展", "你的内力修为不足，无法施展", "你的真气不够，无法施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("force") + me->query("con") * 5", "dp_formula": "target->query_skill("force") + target->query("con") * 5"}, "color_codes": ["CYN", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["= CYN "$n" CYN "见$N" CYN "来势汹涌，急忙提气跃开。\n" NOR"], "success": ["HIR "$N" HIR "倏然跃近，无声无影击出一拳，去势快极，拳影重"
      #                 "重叠叠，直袭$n" HIR "而去。\n"NOR", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK,
      #                                  damage, 90, HIR "$n" HIR "见拳势变换莫测，只是"
      #                                  "微微一愣，已被$N" HIR "一拳正中胸口，神照经内"
      #                                  "劲顿\n时便如山洪爆发一般，透体而入。\n" NOR)"]}, "damage_formula": %{"formula": "ap + random(ap / 2)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-400"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-400"}], "affect_by": ["shenzhao"], "apply_adds": [], "busy_lines": ["me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
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
      # #define YING "「" HIR "无影神拳" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         int damage;
      #         string msg;
      #         int ap, dp;
      #         int lvl;
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         //if (userp(me) && ! me->query("can_perform/shenzhaojing/ying"))
      #           //      return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(YING "只能对战斗中的对手使用。\n");
      # 
      #         if (objectp(me->query_temp("weapon")))
      #                 return notify_fail("你必须空手才能施展" YING "。\n");
      # 
      #         if (me->query_skill_mapped("unarmed") != "shenzhaojing")
      #                 return notify_fail("你没有激发神照经神功为拳脚，无法施展" YING "。\n");
      # 
      #         if (me->query_skill_prepared("unarmed") != "shenzhaojing")
      #                 return notify_fail("你现在没有准备使用神照经神功，无法施展" YING "。\n");
      # 
      #         if ((int)me->query_skill("shenzhaojing", 1) < 200)
      #                 return notify_fail("你的神照经神功火候不够，无法施展" YING "。\n");
      # 
      #         if ((int)me->query_skill("unarmed", 1) < 200)
      #                 return notify_fail("你的基本拳脚火候不够，无法施展" YING "。\n");
      # 
      #         if ((int)me->query("max_neili") < 5000)
      #                 return notify_fail("你的内力修为不足，无法施展" YING "。\n");
      # 
      #         if ((int)me->query("neili") < 500)
      #                 return notify_fail("你的真气不够，无法施展" YING "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIR "$N" HIR "倏然跃近，无声无影击出一拳，去势快极，拳影重"
      #               "重叠叠，直袭$n" HIR "而去。\n"NOR;
      # 
      #         lvl = me->query_skill("shenzhaojing", 1);
      # 
      #         ap = me->query_skill("force") + me->query("con") * 5;
      #         dp = target->query_skill("force") + target->query("con") * 5;
      # 
      #         me->start_busy(3);
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 damage = ap + random(ap / 2);
      #                 me->add("neili", -400);
      #                 target->affect_by("shenzhao", ([
      #                     "level" : me->query("jiali") + random(me->query("jiali")),
      #                         "id"    : me->query("id"),
      #                         "duration" : lvl / 50 + random(lvl / 20) ]));
      #                         msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK,
      #                                damage, 90, HIR "$n" HIR "见拳势变换莫测，只是"
      #                                "微微一愣，已被$N" HIR "一拳正中胸口，神照经内"
      #                                "劲顿\n时便如山洪爆发一般，透体而入。\n" NOR);
      #         } else
      #         {
      #                 msg += CYN "$n" CYN "见$N" CYN "来势汹涌，急忙提气跃开。\n" NOR;
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
end
