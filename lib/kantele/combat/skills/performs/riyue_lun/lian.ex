defmodule Kantele.Combat.Skills.Performs.RiyueLun.Lian do
  @moduledoc """
  perform「五轮连转」（source riyue-lun/lian.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"count", "force"}, {"count", "longxiang-gong"}], "level_gates": [{"force", "250"}, {"longxiang-gong", "90"}, {"riyue-lun", "150"}], "map_gates": [{"hammer", "riyue-lun"}], "prepared_gates": [], "resource_gates": [{"max_neili", "3000"}, {"neili", "500"}], "var_gates": [{"i", "5"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你所使用的武器不对，难以施展", "你没有激发日月轮法，难以施展", "你日月轮法火候不足，难以施展", "你的内功火候不足，难以施展", "你的内力修为不足，难以施展", "你现在的真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIR", "HIW", "HIY", "NOR", "WHT", "YEL"], "combat_messages": %{"fail": [], "other": ["HIY "$N" HIY "嗔目大喝，施展出日月轮法「" HIW "五轮连转"
      #                 HIY "」神技，蓦地将手中" + wp + HIY "飞掷\n而出，幻作数"
      #                 "道光芒，相互盘旋着压向$n" HIY "，招术煞为精奇！\n" NOR", "WHT "突然间锡轮从日月金轮中分离"
      #                                         "开来，化作一道灰芒朝$n" WHT "砸"
      #                                         "去。\n" NOR", "YEL "突然间铜轮从日月金轮中分离"
      #                                         "开来，化作一道黄芒朝$n" YEL "砸"
      #                                         "去。\n" NOR", "HIW "突然间银轮从日月金轮中分离"
      #                                         "开来，化作一道银芒朝$n" HIW "砸"
      #                                         "去。\n" NOR", "HIY "突然间金轮从日月金轮中分离"
      #                                         "开来，化作一道金芒朝$n" HIY "砸"
      #                                         "去。\n" NOR"], "success": ["HIR "突然间铁轮从日月金轮中分离"
      #                                         "开来，化作一道红芒朝$n" HIR "砸"
      #                                         "去。\n" NOR"]}, "resource_adds": [{"neili", "-250"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "hammer"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-250"}], "affect_by": [], "apply_adds": ["attack", "damage"], "busy_lines": ["me->start_busy(1 + random(5));"], "remote_damage": false, "set_flags": [], "temp_set": []}
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
      # #define LIAN "「" HIW "五轮连转" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #     object weapon;
      #     string wp, msg;
      #         int i, count;
      # 
      #         if (userp(me) && ! me->query("can_perform/riyue-lun/lian"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #     if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(LIAN "只能对战斗中的对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon"))
      #            || (string)weapon->query("skill_type") != "hammer")
      #                 return notify_fail("你所使用的武器不对，难以施展" LIAN "。\n");
      # 
      #         if (me->query_skill_mapped("hammer") != "riyue-lun")
      #                 return notify_fail("你没有激发日月轮法，难以施展" LIAN "。\n");
      # 
      #         if ((int)me->query_skill("riyue-lun", 1) < 150)
      #                 return notify_fail("你日月轮法火候不足，难以施展" LIAN "。\n");
      # 
      #         if ((int)me->query_skill("force") < 250)
      #                 return notify_fail("你的内功火候不足，难以施展" LIAN "。\n");
      # 
      #         if ((int)me->query("max_neili") < 3000)
      #                 return notify_fail("你的内力修为不足，难以施展" LIAN "。\n");
      # 
      #         if ((int)me->query("neili") < 500)
      #                 return notify_fail("你现在的真气不足，难以施展" LIAN "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         wp = weapon->name();
      # 
      #         msg = HIY "$N" HIY "嗔目大喝，施展出日月轮法「" HIW "五轮连转"
      #               HIY "」神技，蓦地将手中" + wp + HIY "飞掷\n而出，幻作数"
      #               "道光芒，相互盘旋着压向$n" HIY "，招术煞为精奇！\n" NOR;
      #         message_combatd(msg, me, target);
      # 
      #         if ((int)me->query_skill("longxiang-gong", 1) < 90)
      #                 count = me->query_skill("force", 1) / 8;
      #         else
      #                 count = me->query_skill("longxiang-gong", 1) / 4;
      # 
      #         me->add_temp("apply/attack", count);
      #         me->add_temp("apply/damage", count * 2 / 3);
      # 
      #         for (i = 0; i < 5; i++)
      #         {
      #                 if (! me->is_fighting(target))
      #                         break;
      # 
      #                 if (! weapon->is_item_make()
      #                    && weapon->query("id") == "riyue jinlun")
      #                 {
      #                         switch (i)
      #                         {
      #                         case 0:
      #                                 msg = WHT "突然间锡轮从日月金轮中分离"
      #                                       "开来，化作一道灰芒朝$n" WHT "砸"
      #                                       "去。\n" NOR;
      #                                 break;
      #                         case 1:
      #                                 msg = HIR "突然间铁轮从日月金轮中分离"
      #                                       "开来，化作一道红芒朝$n" HIR "砸"
      #                                       "去。\n" NOR;
      #                                 break;
      #                         case 2:
      #                                 msg = YEL "突然间铜轮从日月金轮中分离"
      #                                       "开来，化作一道黄芒朝$n" YEL "砸"
      #                                       "去。\n" NOR;
      #                                 break;
      #                         case 3:
      #                                 msg = HIW "突然间银轮从日月金轮中分离"
      #                                       "开来，化作一道银芒朝$n" HIW "砸"
      #                                       "去。\n" NOR;
      #                                 break;
      #                         default:
      #                                 msg = HIY "突然间金轮从日月金轮中分离"
      #                                       "开来，化作一道金芒朝$n" HIY "砸"
      #                                       "去。\n" NOR;
      #                                 break;
      #                         }
      #                         message_combatd(msg, me, target);
      #                         COMBAT_D->do_attack(me, target, weapon, 30);
      #                 } else
      #                         COMBAT_D->do_attack(me, target, weapon, 0);
      #         }
      #     me->add("neili", -250);
      #         me->add_temp("apply/attack", -count);
      #         me->add_temp("apply/damage", -count * 2 / 3);
      #     me->start_busy(1 + random(5));
      #     return 1;
      # }
end
