defmodule Kantele.Combat.Skills.Performs.HuaQuan.Juan do
  @moduledoc """
  perform「风卷霹雳上九天」（source hua-quan/juan.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"damage", "cuff"}], "level_gates": [{"force", "180"}, {"hua-quan", "120"}], "map_gates": [{"cuff", "hua-quan"}], "prepared_gates": [{"cuff", "hua-quan"}], "resource_gates": [{"neili", "400"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的西岳华拳不够娴熟，难以施展", "你的内功修为不够，难以施展", "你现在真气不够，难以施展", "你没有激发西岳华拳，难以施展", "你现在没有准备使用西岳华拳，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["CYN", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "只见$N" HIY "身形疾转，双拳聚力齐发，一式「风卷霹雳上九天」携"
      #                 "着隐隐风雷之势贯向$n" HIY "！\n" NOR", "= CYN "$p" CYN "见$P" CYN "拳势汹涌，不敢硬"
      #                          "作抵挡，当即斜斜一跃避开。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 45,
      #                                              HIR "结果$n" HIR "闪避不及，被$P" HIR
      #                                              "双拳贯中，凄然一声惨嚎，口喷鲜血，身"
      #                                              "子向后飞出丈许。\n" NOR)"]}, "damage_formula": %{"formula": "me->query_skill("cuff")"}, "resource_adds": [{"neili", "-250"}, {"neili", "-80"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-250"}, {"neili", "-80"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
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
      # #define JUAN "「" HIY "风卷霹雳上九天" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         // object weapon;
      #         int damage;
      #         string msg;
      # 
      #         if (userp(me) && ! me->query("can_perform/hua-quan/juan"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(JUAN "只能对战斗中的对手使用。\n");
      # 
      #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
      #                 return notify_fail(JUAN "只能空手施展。\n");
      # 
      #         if ((int)me->query_skill("hua-quan", 1) < 120)
      #                 return notify_fail("你的西岳华拳不够娴熟，难以施展" JUAN "。\n");
      # 
      #         if ((int)me->query_skill("force") < 180)
      #                 return notify_fail("你的内功修为不够，难以施展" JUAN "。\n");
      # 
      #         if ((int)me->query("neili") < 400)
      #                 return notify_fail("你现在真气不够，难以施展" JUAN "。\n");
      # 
      #         if (me->query_skill_mapped("cuff") != "hua-quan")
      #                 return notify_fail("你没有激发西岳华拳，难以施展" JUAN "。\n");
      # 
      #         if (me->query_skill_prepared("cuff") != "hua-quan")
      #                 return notify_fail("你现在没有准备使用西岳华拳，难以施展" JUAN "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIY "只见$N" HIY "身形疾转，双拳聚力齐发，一式「风卷霹雳上九天」携"
      #               "着隐隐风雷之势贯向$n" HIY "！\n" NOR;
      # 
      #         if (random(me->query_skill("cuff")) > target->query_skill("dodge") / 2)
      #         {
      #                 me->start_busy(2);
      #                 damage = me->query_skill("cuff");
      #                 damage = damage / 2 + random(damage);
      #                 me->add("neili", -250);
      #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 45,
      #                                            HIR "结果$n" HIR "闪避不及，被$P" HIR
      #                                            "双拳贯中，凄然一声惨嚎，口喷鲜血，身"
      #                                            "子向后飞出丈许。\n" NOR);
      #         } else
      #         {
      #                 me->start_busy(3);
      #                 me->add("neili", -80);
      #                 msg += CYN "$p" CYN "见$P" CYN "拳势汹涌，不敢硬"
      #                        "作抵挡，当即斜斜一跃避开。\n" NOR;
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
end
