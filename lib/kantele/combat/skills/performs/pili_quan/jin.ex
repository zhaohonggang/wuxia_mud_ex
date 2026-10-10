defmodule Kantele.Combat.Skills.Performs.PiliQuan.Jin do
  @moduledoc """
  perform「紫雷劲」（source pili-quan/jin.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "cuff"}, {"dp", "parry"}], "level_gates": [{"pili-quan", "40"}], "map_gates": [], "prepared_gates": [{"cuff", "pili-quan"}], "resource_gates": [{"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的霹雳神拳不够娴熟，无法施展", "你现在真气不够，无法施展", "你没有准备使用霹雳神拳，无法施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("cuff")", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["HIC", "HIR", "HIW", "HIY", "MAG", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "$N" HIY "身形一转，运力与双拳，施出绝招「" HIW "紫雷劲" HIY "」，双拳迅猛无比"
      #                 "的袭向$n" HIY "。\n" NOR", "= HIC "可是$p" HIC "奋力招架，硬生生的挡开了$P"
      #                          HIC "这一招。\n"NOR"], "success": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 55,
      #                                      HIR "只见$P" HIR "这一拳把$p" HIR
      #                                              "飞了出去，重重的摔在地上，吐血不止！\n" NOR)"]}, "damage_formula": %{"formula": "ap + random(ap / 2)"}, "hit_formula": %{"left_side": "ap * 2 / 3 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-120"}, {"neili", "-80"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-120"}, {"neili", "-80"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // 紫雷劲
      # 
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # inherit F_SSERVER;
      # 
      # #define PO "「" MAG "紫雷劲" NOR "」"
      # 
      # int perform(object me, object target)
      # {
      #     // object weapon;
      #     int damage;
      #     string msg;
      #         int ap, dp;
      # 
      #         if (! target)
      #         {
      #             me->clean_up_enemy();
      #             target = me->select_opponent();
      #         }
      # 
      #         if (userp(me) && ! me->query("can_perform/pili-quan/jin"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #     if (! target || ! me->is_fighting(target))
      #         return notify_fail(PO "只能对战斗中的对手使用。\n");
      # 
      #     if ((int)me->query_skill("pili-quan", 1) < 40)
      #         return notify_fail("你的霹雳神拳不够娴熟，无法施展" PO "。\n");
      # 
      #     if ((int)me->query("neili") < 200)
      #         return notify_fail("你现在真气不够，无法施展" PO "。\n");
      # 
      #         if (me->query_skill_prepared("cuff") != "pili-quan")
      #                 return notify_fail("你没有准备使用霹雳神拳，无法施展" PO "。\n");
      # 
      #         if (! living(target))
      #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #     msg = HIY "$N" HIY "身形一转，运力与双拳，施出绝招「" HIW "紫雷劲" HIY "」，双拳迅猛无比"
      #               "的袭向$n" HIY "。\n" NOR;
      # 
      #         ap = me->query_skill("cuff");
      #         dp = target->query_skill("parry");
      #     if (ap * 2 / 3 + random(ap) > dp)
      #     {
      #         damage = ap + random(ap / 2);
      # 
      #                 me->add("neili", -120);
      #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 55,
      #                                    HIR "只见$P" HIR "这一拳把$p" HIR
      #                                            "飞了出去，重重的摔在地上，吐血不止！\n" NOR);
      #         me->start_busy(2);
      #     } else
      #     {
      #         msg += HIC "可是$p" HIC "奋力招架，硬生生的挡开了$P"
      #                        HIC "这一招。\n"NOR;
      #         me->add("neili", -80);
      #         me->start_busy(3);
      #     }
      #     message_combatd(msg, me, target);
      # 
      #     return 1;
      # }
end
