defmodule Kantele.Combat.Skills.Performs.JuemingTui.Jue do
  @moduledoc """
  perform「绝命一踢」（source jueming-tui/jue.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "unarmed"}, {"dp", "dodge"}, {"pp", "parry"}], "level_gates": [{"jueming-tui", "80"}], "map_gates": [{"unarmed", "jueming-tui"}], "prepared_gates": [{"unarmed", "jueming-tui"}], "resource_gates": [{"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你绝命腿法不够娴熟，难以施展", "你没有激发绝命腿法，难以施展", "你没有准备绝命腿法，难以施展", "你目前的内力不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("unarmed") + me->query("str") * 10", "dp_formula": "target->query_skill("dodge") + target->query("dex") * 10"}, "color_codes": ["CYN", "HIC", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["= HIC "可是$n" HIC "身子一晃，硬生生架住了$N" HIC "这一腿。\n" NOR", "= CYN "却见$n" CYN "镇定的向后一纵，闪开了$N" CYN "这一腿。\n" NOR"], "success": ["HIR "只听$N" HIR "一声冷哼，侧身飞踢，右腿横"
      #                     "扫向$n" HIR "，当真是力不可挡。\n" NOR", "HIR "$N" HIR "蓦地大喝一声，单腿猛踢而出，直"
      #                     "踹$n" HIR "腰际，招式极为迅猛。\n" NOR", "HIR "突然只见$N" HIR "双腿连环踢出，挟着嚯嚯"
      #                     "风声，以千钧之势扫向$n" HIR "。\n" NOR", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 60,
      #                                      HIR "$n" HIR "连忙格挡，却只觉得力道大"
      #                                          "得出奇，登时被一脚踢得飞起。\n" NOR)"]}, "damage_formula": %{"formula": "ap / 3 + random(ap / 3)"}, "hit_formula": %{"left_side": "ap * 7 / 10 + random(ap)", "operator": "<", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}, {"neili", "-30"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-30"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(3);", "me->start_busy(3);", "me->start_busy(2);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3);
      #   - me->start_busy(3);
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
      # #define JUE "「" HIR "绝命一踢" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #     string msg;
      #     int ap, dp, pp;
      #     int damage;
      # 
      #     if (userp(me) && !me->query("can_perform/jueming-tui/jue"))
      #         return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #     if (!target)
      #     {
      #         me->clean_up_enemy();
      #         target = me->select_opponent();
      #     }
      # 
      #     if (!target || !me->is_fighting(target))
      #         return notify_fail(JUE "只能对战斗中的对手使用。\n");
      # 
      #     if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
      #         return notify_fail(JUE "只能空手施展。\n");
      # 
      #     if (me->query_skill("jueming-tui", 1) < 80)
      #         return notify_fail("你绝命腿法不够娴熟，难以施展" JUE "。\n");
      # 
      #     if (me->query_skill_mapped("unarmed") != "jueming-tui")
      #         return notify_fail("你没有激发绝命腿法，难以施展" JUE "。\n");
      # 
      #     if (me->query_skill_prepared("unarmed") != "jueming-tui")
      #         return notify_fail("你没有准备绝命腿法，难以施展" JUE "。\n");
      # 
      #     if (me->query("neili") < 200)
      #         return notify_fail("你目前的内力不够，难以施展" JUE "。\n");
      # 
      #     if (!living(target))
      #         return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #     switch (random(3))
      #     {
      #     case 0:
      #         msg = HIR "只听$N" HIR "一声冷哼，侧身飞踢，右腿横"
      #                   "扫向$n" HIR "，当真是力不可挡。\n" NOR;
      #         break;
      # 
      #     case 1:
      #         msg = HIR "$N" HIR "蓦地大喝一声，单腿猛踢而出，直"
      #                   "踹$n" HIR "腰际，招式极为迅猛。\n" NOR;
      #         break;
      # 
      #     default:
      #         msg = HIR "突然只见$N" HIR "双腿连环踢出，挟着嚯嚯"
      #                   "风声，以千钧之势扫向$n" HIR "。\n" NOR;
      #         break;
      #     }
      # 
      #     ap = me->query_skill("unarmed") + me->query("str") * 10;
      #     dp = target->query_skill("dodge") + target->query("dex") * 10;
      #     pp = target->query_skill("parry") + target->query("str") * 10;
      # 
      #     if (ap * 7 / 10 + random(ap) < pp)
      #     {
      #         msg += HIC "可是$n" HIC "身子一晃，硬生生架住了$N" HIC "这一腿。\n" NOR;
      #         me->start_busy(3);
      #         me->add("neili", -30);
      #     }
      #     else if (ap * 7 / 10 + random(ap) < dp)
      #     {
      #         msg += CYN "却见$n" CYN "镇定的向后一纵，闪开了$N" CYN "这一腿。\n" NOR;
      #         me->start_busy(3);
      #         me->add("neili", -30);
      #     }
      #     else
      #     {
      #         damage = ap / 3 + random(ap / 3);
      #         msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 60,
      #                                    HIR "$n" HIR "连忙格挡，却只觉得力道大"
      #                                        "得出奇，登时被一脚踢得飞起。\n" NOR);
      #         me->start_busy(2);
      #         me->add("neili", -100);
      #     }
      #     message_combatd(msg, me, target);
      #     return 1;
      # }
end
