defmodule Kantele.Combat.Skills.Performs.XiantianGong.Hun do
  @moduledoc """
  perform「天地混元」（source xiantian-gong/hun.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "unarmed"}, {"dp", "parry"}], "level_gates": [{"xiantian-gong", "200"}], "map_gates": [{"force", "xiantian-gong"}, {"unarmed", "xiantian-gong"}], "prepared_gates": [{"unarmed", "xiantian-gong"}], "resource_gates": [{"max_neili", "4000"}, {"neili", "500"}], "var_gates": [{"i", "5"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的先天功修为不够，难以施展", "你的内力修为不足，难以施展", "你没有激发先天功为拳脚，难以施展", "你没有激发先天功为内功，难以施展", "你没有准备使用先天功，难以施展", "你现在的真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("unarmed") + me->query("con") * 10", "dp_formula": "target->query_skill("parry") + target->query("dex") * 10"}, "color_codes": ["HIR", "HIW", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "\n$N" HIW "施出天地混元，全身真气急速运转，引得周围气流波"
      #                 "动不已，层层叠叠涌向$n" HIW "！\n" NOR", "= HIY "$n" HIY "见$p" HIY "来势迅猛之极，甚难防备，连"
      #                          "忙振作精神，小心抵挡。\n" NOR"], "success": ["= HIR "$n" HIR "见$P" HIR "来势迅猛之极，一时不知该如"
      #                          "何作出抵挡，竟呆立当场。\n" NOR"]}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-280"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-280"}], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["if (random(5) < 2 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(5));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (random(5) < 2 && ! target->is_busy())
      #   - target->start_busy(1);
      #   - me->start_busy(1 + random(5));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define HUN "「" HIW "天地混元" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         // object weapon;
      #         int ap, dp;
      #         int i, count;
      #         string msg;
      # 
      #         if (userp(me) && ! me->query("can_perform/xiantian-gong/hun"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(HUN "只能对战斗中的对手使用。\n");
      # 
      #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
      #                 return notify_fail(HUN "只能空手施展。\n");
      # 
      #         if ((int)me->query_skill("xiantian-gong", 1) < 200)
      #                 return notify_fail("你的先天功修为不够，难以施展" HUN "。\n");
      # 
      #         if (me->query("max_neili") < 4000)
      #                 return notify_fail("你的内力修为不足，难以施展" HUN "。\n");
      # 
      #         if (me->query_skill_mapped("unarmed") != "xiantian-gong")
      #                 return notify_fail("你没有激发先天功为拳脚，难以施展" HUN "。\n");
      # 
      #         if (me->query_skill_mapped("force") != "xiantian-gong")
      #                 return notify_fail("你没有激发先天功为内功，难以施展" HUN "。\n");
      # 
      #         if (me->query_skill_prepared("unarmed") != "xiantian-gong")
      #                 return notify_fail("你没有准备使用先天功，难以施展" HUN "。\n");
      # 
      #         if (me->query("neili") < 500)
      #                 return notify_fail("你现在的真气不足，难以施展" HUN "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIW "\n$N" HIW "施出天地混元，全身真气急速运转，引得周围气流波"
      #               "动不已，层层叠叠涌向$n" HIW "！\n" NOR;
      # 
      #         ap = me->query_skill("unarmed") + me->query("con") * 10;
      #         dp = target->query_skill("parry") + target->query("dex") * 10;
      # 
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 count = ap / 10;
      #                 msg += HIR "$n" HIR "见$P" HIR "来势迅猛之极，一时不知该如"
      #                        "何作出抵挡，竟呆立当场。\n" NOR;
      #         } else
      #         {
      #                 msg += HIY "$n" HIY "见$p" HIY "来势迅猛之极，甚难防备，连"
      #                        "忙振作精神，小心抵挡。\n" NOR;
      #                 count = 0;
      #         }
      # 
      #         message_vision(msg, me, target);
      #         me->add_temp("apply/attack", count);
      # 
      #         me->add("neili", -280);
      # 
      #         for (i = 0; i < 5; i++)
      #         {
      #                 if (! me->is_fighting(target))
      #                         break;
      #                 if (random(5) < 2 && ! target->is_busy())
      #                         target->start_busy(1);
      # 
      #                 COMBAT_D->do_attack(me, target, 0, 0);
      #         }
      # 
      #         me->start_busy(1 + random(5));
      #         me->add_temp("apply/attack", -count);
      # 
      #         return 1;
      # }
end
