defmodule Kantele.Combat.Skills.Performs.XuanmingZhang.Ying do
  @moduledoc """
  perform「如影相随」（source xuanming-zhang/ying.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "strike"}, {"dp", "dodge"}], "level_gates": [{"dodge", "180"}, {"xuanming-zhang", "100"}], "map_gates": [{"strike", "xuanming-zhang"}], "prepared_gates": [{"strike", "xuanming-zhang"}], "resource_gates": [{"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你玄冥神掌不够娴熟，难以施展", "你没有激发玄冥神掌，难以施展", "你没有准备玄冥神掌，难以施展", "你的轻功修为不够，难以施展", "你现在的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("strike")", "dp_formula": "target->query_skill("dodge")"}, "color_codes": ["CYN", "HIC", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": ["CYN "$n" CYN "看破$N" CYN "毫无攻击之意，于"
      #                         "是大胆反攻，将$N" CYN "这招尽数化解。\n" NOR"], "other": ["HIC "\n$N" HIC "长啸一声，施出绝招「" HIW "如影相随" HIC "」，"
      #                 "双掌不断翻腾，掌风中透出阵阵阴寒之气，将$n" HIC "笼罩。\n" NOR"], "success": ["HIR "$n" HIR "顿觉寒气避人，一时间无从应对，"
      #                         "竟被困在$N" HIR "的掌风之中。\n" NOR"]}, "hit_formula": %{"left_side": "ap * 2 / 3 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}, {"neili", "-180"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-180"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (target->is_busy())", "target->start_busy(1 + ap / 18);", "me->start_busy(1);", "me->start_busy(2);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (target->is_busy())
      #   - target->start_busy(1 + ap / 18);
      #   - me->start_busy(1);
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
      # #define YING "「" HIW "如影相随" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         string msg;
      #         int ap, dp;
      # 
      #         if (userp(me) && ! me->query("can_perform/xuanming-zhang/ying"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(YING "只能对战斗中的对手使用。\n");
      # 
      #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
      #                 return notify_fail(YING "只能空手施展。\n");
      # 
      #         if (target->is_busy())
      #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
      # 
      #         if ((int)me->query_skill("xuanming-zhang", 1) < 100)
      #                 return notify_fail("你玄冥神掌不够娴熟，难以施展" YING "。\n");
      # 
      #         if (me->query_skill_mapped("strike") != "xuanming-zhang")
      #                 return notify_fail("你没有激发玄冥神掌，难以施展" YING "。\n");
      # 
      #         if (me->query_skill_prepared("strike") != "xuanming-zhang")
      #                 return notify_fail("你没有准备玄冥神掌，难以施展" YING "。\n");
      # 
      #         if (me->query_skill("dodge") < 180)
      #                 return notify_fail("你的轻功修为不够，难以施展" YING "。\n");
      # 
      #         if ((int)me->query("neili") < 200)
      #                 return notify_fail("你现在的真气不够，难以施展" YING "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         ap = me->query_skill("strike");
      # 
      #         dp = target->query_skill("dodge");
      # 
      #         msg = HIC "\n$N" HIC "长啸一声，施出绝招「" HIW "如影相随" HIC "」，"
      #               "双掌不断翻腾，掌风中透出阵阵阴寒之气，将$n" HIC "笼罩。\n" NOR;
      #         message_sort(msg, me, target);
      # 
      #         if (ap * 2 / 3 + random(ap) > dp)
      #         {
      #         msg = HIR "$n" HIR "顿觉寒气避人，一时间无从应对，"
      #                       "竟被困在$N" HIR "的掌风之中。\n" NOR;
      # 
      #                 target->start_busy(1 + ap / 18);
      #                    me->start_busy(1);
      #                 me->add("neili", -180);
      #         } else
      #         {
      #                 msg = CYN "$n" CYN "看破$N" CYN "毫无攻击之意，于"
      #                       "是大胆反攻，将$N" CYN "这招尽数化解。\n" NOR;
      # 
      #                 me->start_busy(2);
      #                 me->add("neili", -100);
      #         }
      #         message_vision(msg, me, target);
      # 
      #         return 1;
      # }
end
