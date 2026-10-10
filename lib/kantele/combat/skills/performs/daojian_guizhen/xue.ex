defmodule Kantele.Combat.Skills.Performs.DaojianGuizhen.Xue do
  @moduledoc """
  perform「天下有」（source daojian-guizhen/xue.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "daojian-guizhen"}, {"dp", "parry"}], "level_gates": [{"daojian-guizhen", "200"}, {"daojian-guizhen", "250"}], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "500"}], "var_gates": [{"i", "9"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你所使用的武器不对，难以施展", "你的", "你没有激发刀剑归真，难以施展", "你的刀剑归真等级不够，难以施展", "你现在的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("daojian-guizhen", 1) * 3 / 2 +
      #                me->query_skill("martial-cognize", 1)", "dp_formula": "target->query_skill("parry") +
      #                target->query_skill("martial-cognize", 1)"}, "color_codes": ["HIG", "HIR", "HIW", "NOR", "WHT"], "combat_messages": %{"fail": [], "other": ["= HIW "$n" HIW "只见无数刀光剑影向自己逼"
      #                          "来，顿感眼花缭乱，心底寒意油然而生。\n" NOR", "= HIG "$n" HIG "突然发现自己四周皆被刀光"
      #                          "剑影所包围，心知不妙，急忙小心招架。\n" NOR"], "success": ["HIW "$N" HIW "手中" + weapon->name() + HIW "蓦地一抖"
      #                 "，将「" NOR + WHT "胡家刀法" HIW "」并「" NOR + WHT
      #                 "苗家剑法" HIW "」连环施出。霎时寒\n光点点，犹如夜陨"
      #                 "划空，铺天盖地罩向$n" HIW "，正是一招「" HIW "天下"
      #                 "有" HIR "血" HIW "」。\n" NOR"]}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-300"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-300"}], "affect_by": [], "apply_adds": ["attack", "damage"], "busy_lines": ["me->start_busy(1 + random(8));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1 + random(8));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define XUE "「" HIW "天下有" HIR "血" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         string type, msg;
      #         object weapon;
      #         int i, count;
      #         int ap, dp;
      # 
      #         if (me->query_skill("daojian-guizhen", 1) < 200)
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target)
      #         {
      #                 me->clean_up_enemy();
      #                 target = me->select_opponent();
      #         }
      # 
      #         if (! me->is_fighting(target))
      #                 return notify_fail(XUE "只能对战斗中的对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon"))
      #            || (string)weapon->query("skill_type") != "sword"
      #            && (string)weapon->query("skill_type") != "blade" )
      #                 return notify_fail("你所使用的武器不对，难以施展" XUE "。\n");
      # 
      #         type = weapon->query("skill_type");
      # 
      #         if (me->query_skill(type, 1) < 250)
      #                 return notify_fail("你的" + to_chinese(type) + "太差，"
      #                                    "难以施展" XUE "。\n");
      # 
      #         if (me->query_skill_mapped(type) != "daojian-guizhen")
      #                 return notify_fail("你没有激发刀剑归真，难以施展" XUE "。\n");
      # 
      #         if (me->query_skill("daojian-guizhen", 1) < 250)
      #                 return notify_fail("你的刀剑归真等级不够，难以施展" XUE "。\n");
      # 
      #         if (me->query("neili") < 500)
      #                 return notify_fail("你现在的真气不够，难以施展" XUE "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIW "$N" HIW "手中" + weapon->name() + HIW "蓦地一抖"
      #               "，将「" NOR + WHT "胡家刀法" HIW "」并「" NOR + WHT
      #               "苗家剑法" HIW "」连环施出。霎时寒\n光点点，犹如夜陨"
      #               "划空，铺天盖地罩向$n" HIW "，正是一招「" HIW "天下"
      #               "有" HIR "血" HIW "」。\n" NOR;
      # 
      #         ap = me->query_skill("daojian-guizhen", 1) * 3 / 2 +
      #              me->query_skill("martial-cognize", 1);
      # 
      #         dp = target->query_skill("parry") +
      #              target->query_skill("martial-cognize", 1);
      # 
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 msg += HIW "$n" HIW "只见无数刀光剑影向自己逼"
      #                        "来，顿感眼花缭乱，心底寒意油然而生。\n" NOR;
      #                 count = ap / 6;
      #                 me->set_temp("daojian-guizhen/max_pfm", 1);
      #         } else
      #         {
      #                 msg += HIG "$n" HIG "突然发现自己四周皆被刀光"
      #                        "剑影所包围，心知不妙，急忙小心招架。\n" NOR;
      #                 count = ap / 12;
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         me->add("neili", -300);
      #         me->add_temp("apply/attack", count);
      #         me->add_temp("apply/damage", count * 2 / 3);
      # 
      #         for (i = 0; i < 9; i++)
      #         {
      #                 if (! me->is_fighting(target))
      #                         break;
      # 
      #                 COMBAT_D->do_attack(me, target, weapon, 0);
      #         }
      #         me->add_temp("apply/attack", -count);
      #         me->add_temp("apply/damage", -count * 2 / 3);
      #         me->delete_temp("daojian-guizhen/max_pfm");
      #         me->start_busy(1 + random(8));
      #         return 1;
      # }
end
