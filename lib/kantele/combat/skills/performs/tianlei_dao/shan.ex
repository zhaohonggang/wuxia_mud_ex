defmodule Kantele.Combat.Skills.Performs.TianleiDao.Shan do
  @moduledoc """
  perform「五雷连闪」（source tianlei-dao/shan.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "blade"}, {"dp", "dodge"}], "level_gates": [{"dodge", "180"}, {"tianlei-dao", "150"}], "map_gates": [{"blade", "tianlei-dao"}], "prepared_gates": [], "resource_gates": [{"neili", "300"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你天雷绝刀不够娴熟，难以施展", "你没有激发天雷绝刀，难以施展", "你的轻功修为不够，难以施展", "你现在的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("blade")", "dp_formula": "target->query_skill("dodge")"}, "color_codes": ["HIC", "HIG", "HIW", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "\n$N" HIY "将手中" + wn + HIY "立于胸前，施出绝招「" HIW "五"
      #                 "雷连闪" HIY "」，$N身法陡然加快，手中" + wn + HIY "连续砍出五刀，"
      #                 "刀法之精妙，令人匪夷所思。\n" NOR", "HIG "$n" HIG "见$P" HIG "这招来势汹涌，势不可"
      #                        "挡，被$N" HIG "攻得连连后退。\n" NOR", "HIC "$n" HIC "见$N" HIC "这几刀来势迅猛无比，毫"
      #                         "无破绽，只得小心应付。\n" NOR"], "success": []}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-180"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "blade"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-180"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (target->is_busy())", "me->start_busy(1 + random(attack_time));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (target->is_busy())
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
      # #define SHAN "「" HIW "五雷连闪" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #     object weapon;
      #     string msg, wn;
      #     int ap, dp;
      #         int i, attack_time;
      # 
      #         if (userp(me) && ! me->query("can_perform/tianlei-dao/shan"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(SHAN "只能对战斗中的对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon")) ||
      #             (string)weapon->query("skill_type") != "blade")
      #         return notify_fail("你使用的武器不对，难以施展" SHAN "。\n");
      # 
      #         if (target->is_busy())
      #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
      # 
      #         if ((int)me->query_skill("tianlei-dao", 1) < 150)
      #                 return notify_fail("你天雷绝刀不够娴熟，难以施展" SHAN "。\n");
      # 
      #         if (me->query_skill_mapped("blade") != "tianlei-dao")
      #                 return notify_fail("你没有激发天雷绝刀，难以施展" SHAN "。\n");
      # 
      #         if (me->query_skill("dodge") < 180)
      #                 return notify_fail("你的轻功修为不够，难以施展" SHAN "。\n");
      # 
      #         if ((int)me->query("neili") < 300)
      #                 return notify_fail("你现在的真气不够，难以施展" SHAN "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      # 
      #         wn = weapon->name();
      # 
      #     msg = HIY "\n$N" HIY "将手中" + wn + HIY "立于胸前，施出绝招「" HIW "五"
      #               "雷连闪" HIY "」，$N身法陡然加快，手中" + wn + HIY "连续砍出五刀，"
      #               "刀法之精妙，令人匪夷所思。\n" NOR;
      # 
      #         message_sort(msg, me, target);
      # 
      #         attack_time = 5;
      # 
      #     ap = me->query_skill("blade");
      #     dp = target->query_skill("dodge");
      # 
      #     me->add("neili", -180);
      # 
      #     if (ap / 2 + random(ap) > dp)
      #     {
      #         msg = HIG "$n" HIG "见$P" HIG "这招来势汹涌，势不可"
      #                      "挡，被$N" HIG "攻得连连后退。\n" NOR;
      #         } else
      #         {
      #                 msg = HIC "$n" HIC "见$N" HIC "这几刀来势迅猛无比，毫"
      #                       "无破绽，只得小心应付。\n" NOR;
      #         }
      # 
      #         message_combatd(msg, me, target);
      # 
      #         for (i = 0; i < attack_time; i++)
      #         {
      #                 if (! me->is_fighting(target))
      #                         break;
      # 
      #                 COMBAT_D->do_attack(me, target, weapon, 15);
      #         }
      # 
      #     me->start_busy(1 + random(attack_time));
      # 
      #         return 1;
      # }
end
