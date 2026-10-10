defmodule Kantele.Combat.Skills.Performs.KuangfengJian.Yong do
  @moduledoc """
  perform「风起云涌」（source kuangfeng-jian/yong.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "sword"}, {"dp", "parry"}], "level_gates": [{"dodge", "140"}, {"kuangfeng-jian", "140"}], "map_gates": [{"sword", "kuangfeng-jian"}], "prepared_gates": [], "resource_gates": [{"neili", "250"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你的基本轻功的修为不够，难以施展", "你的狂风快剑修为不够，难以施展", "你没有激发狂风快剑，难以施展", "你现在真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("sword") + me->query_skill("dodge")", "dp_formula": "target->query_skill("parry") + target->query_skill("dodge")"}, "color_codes": ["CYN", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "$N" HIW "凝神聚气，运转手中" + weapon->name() + HIW "，刹那间犹如"
      #                 "狂风骤起，风声萧萧，" + weapon->name() + HIW "猛地卷向$n" HIW "。\n" NOR", "= CYN "可是$n" CYN "微微一笑，轻轻格躲开了$N"
      #                          CYN "的剑招。\n"NOR"], "success": ["= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 65 + random(6),
      #                                              HIR "$n" HIR "看得目瞪口呆，只觉一阵狂风吹过，" + weapon->name() + HIR 
      #                                              "却已透胸而过。\n" NOR)"]}, "damage_formula": %{"formula": "ap + random(ap / 2)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "- 230"}, {"neili", "-120"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-120"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(2);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
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
      # #define YONG "「" HIW "风起云涌" NOR "」"
      # 
      # inherit F_SSERVER;
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
      #         if (userp(me) && ! me->query("can_perform/kuangfeng-jian/yong"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(YONG "只能在战斗中对对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon")) ||
      #               (string)weapon->query("skill_type") != "sword")
      #                 return notify_fail("你使用的武器不对，难以施展" YONG "。\n");
      # 
      #         if (me->query_skill("dodge", 1) < 140)
      #                 return notify_fail("你的基本轻功的修为不够，难以施展" YONG "。\n");
      # 
      #         if (me->query_skill("kuangfeng-jian", 1) < 140)
      #                 return notify_fail("你的狂风快剑修为不够，难以施展" YONG "。\n");
      # 
      #         if (me->query_skill_mapped("sword") != "kuangfeng-jian")
      #                 return notify_fail("你没有激发狂风快剑，难以施展" YONG "。\n");
      # 
      #         if (me->query("neili") < 250)
      #                 return notify_fail("你现在真气不够，难以施展" YONG "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIW "$N" HIW "凝神聚气，运转手中" + weapon->name() + HIW "，刹那间犹如"
      #               "狂风骤起，风声萧萧，" + weapon->name() + HIW "猛地卷向$n" HIW "。\n" NOR;
      # 
      #         ap = me->query_skill("sword") + me->query_skill("dodge");
      #         dp = target->query_skill("parry") + target->query_skill("dodge");
      # 
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 damage = ap + random(ap / 2);
      #                 me->add("neili", - 230);
      #                 me->start_busy(2);
      #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 65 + random(6),
      #                                            HIR "$n" HIR "看得目瞪口呆，只觉一阵狂风吹过，" + weapon->name() + HIR 
      #                                            "却已透胸而过。\n" NOR);
      #         } else
      #         {
      #                 me->add("neili", -120);
      #                 me->start_busy(2);
      #                 msg += CYN "可是$n" CYN "微微一笑，轻轻格躲开了$N"
      #                        CYN "的剑招。\n"NOR;
      #         }
      # 
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
end
