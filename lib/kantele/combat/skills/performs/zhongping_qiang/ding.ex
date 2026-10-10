defmodule Kantele.Combat.Skills.Performs.ZhongpingQiang.Ding do
  @moduledoc """
  perform「定岳七方」（source zhongping-qiang/ding.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "club"}, {"dp", "parry"}], "level_gates": [{"force", "180"}, {"zhongping-qiang", "120"}], "map_gates": [{"club", "zhongping-qiang"}], "prepared_gates": [], "resource_gates": [{"max_neili", "2000"}, {"neili", "200"}], "var_gates": [{"i", "7"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你所使用的武器不对，难以施展", "你中平枪法不够娴熟，难以施展", "你没有激发中平枪法，难以施展", "你的内功火候不够，难以施展", "你的内力修为不够，难以施展", "你现在的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("club")", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["HIC", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["= HIC "$n" HIC "见$N" HIC "攻势凶猛异常，实非"
      #                          "寻常，急忙打起精神，小心应付开来。\n" NOR"], "success": ["HIY "$N" HIY "身形一转，施出中平枪法绝技「" HIR "定岳七方"
      #                 HIY "」，手中" + weapon->name() + HIY "接连七刺，枪枪不离"
      #                "$n" HIY "要害！\n" NOR", "= HIR "$n" HIR "见$N" HIR "攻势凶猛异常，实非"
      #                          "寻常，不由心生寒意，招架登时散乱。\n" NOR"]}, "hit_formula": %{"left_side": "ap / 2 + random(ap * 2)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-7 * 20"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "club"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(1 + random(7));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1 + random(7));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define DING "「" HIY "定岳七方" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #     object weapon;
      #     string msg;
      #     int i, ap, dp;
      # 
      #         if (userp(me) && ! me->query("can_perform/zhongping-qiang/ding"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #     if (! target) target = offensive_target(me);
      # 
      #     if (! target || ! me->is_fighting(target))
      #                 return notify_fail(DING "只能对战斗中的对手使用。\n");
      # 
      #     if (! objectp(weapon = me->query_temp("weapon")) ||
      #             (string)weapon->query("skill_type") != "club")
      #                 return notify_fail("你所使用的武器不对，难以施展" DING "。\n");
      # 
      #         if ((int)me->query_skill("zhongping-qiang", 1) < 120)
      #                 return notify_fail("你中平枪法不够娴熟，难以施展" DING "。\n");
      # 
      #         if (me->query_skill_mapped("club") != "zhongping-qiang")
      #                 return notify_fail("你没有激发中平枪法，难以施展" DING "。\n");
      # 
      #         if ((int)me->query_skill("force") < 180 )
      #                 return notify_fail("你的内功火候不够，难以施展" DING "。\n");
      # 
      #         if ((int)me->query("max_neili") < 2000)
      #                 return notify_fail("你的内力修为不够，难以施展" DING "。\n");
      # 
      #         if ((int)me->query("neili") < 200)
      #                 return notify_fail("你现在的真气不够，难以施展" DING "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #     msg = HIY "$N" HIY "身形一转，施出中平枪法绝技「" HIR "定岳七方"
      #               HIY "」，手中" + weapon->name() + HIY "接连七刺，枪枪不离"
      #              "$n" HIY "要害！\n" NOR;
      # 
      #     ap = me->query_skill("club");
      #     dp = target->query_skill("parry");
      # 
      #     if (ap / 2 + random(ap * 2) > dp)
      #     {
      #         msg += HIR "$n" HIR "见$N" HIR "攻势凶猛异常，实非"
      #                        "寻常，不由心生寒意，招架登时散乱。\n" NOR;
      #         } else
      #         {
      #                 msg += HIC "$n" HIC "见$N" HIC "攻势凶猛异常，实非"
      #                        "寻常，急忙打起精神，小心应付开来。\n" NOR;
      #         }
      #     message_combatd(msg, me, target);
      # 
      #     me->add("neili", -7 * 20);
      # 
      #     for (i = 0; i < 7; i++)
      #     {
      #         if (! me->is_fighting(target))
      #             break;
      #         COMBAT_D->do_attack(me, target, weapon, 0);
      #     }
      #     me->start_busy(1 + random(7));
      # 
      #     return 1;
      # }
end
