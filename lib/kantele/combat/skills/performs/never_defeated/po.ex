defmodule Kantele.Combat.Skills.Performs.NeverDefeated.Po do
  @moduledoc """
  perform「po」（source never-defeated/po.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"dp", "parry"}, {"skill", "never-defeated"}, {"skill2", "martial-cognize"}], "level_gates": [], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "150"}], "var_gates": [{"skill", "100"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["破字诀只能对战斗中的对手使用。\n", "你必须手持兵刃才能施展破字诀！\n", "你的", "你没有激发不败神功，无法施展破字诀！\n", "你的不败神功等级不够，无法施展破字诀！\n", "你现在真气不够！\n", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "skill * 3 / 2 + skill2 * 3 / 2", "dp_formula": "target->query_skill("parry") +
      #                target->query_skill("martial-cognize", 1)"}, "color_codes": ["HIC", "HIW", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIC "$N" HIC "手中" + weapon->name() +
      #                 HIC "一抖，犹如夜雨流星，铺天盖地的攻向$n"
      #                 HIC "，没有半点规矩可循。\n" NOR", "= HIY "$n" HIY "见来招即巧又拙，不同于人间"
      #                                  "任何招式，不禁大为慌乱，一时破绽迭出，$N"
      #                                  HIY "见状连出" + chinese_number(n) + "招！\n" NOR", "HIW "$n" HIW "觉得眼前眼花缭乱，手中的" + weapon2->name() +
      #                                         HIW "一时竟然拿捏不住，脱手而出！\n" NOR", "HIY "$n竭力抵挡，一时间再也无力反击。\n" NOR", "= HIY "$n" HIY "只办了个勉力遮挡，全然无法反击。\n" NOR", "= HIC "不过$n" HIC "一丝不苟，严守门户，没有露出半点破绽。\n" NOR"], "success": []}, "hit_formula": %{"left_side": "ap / 2 + random(ap * 2)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(1 + random(n));", "if (random(2) && ! target->is_busy())", "target->start_busy(1);", "target->start_busy(4 + random(skill / 30));", "me->start_busy(3 + random(2));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1 + random(n));
      #   - if (random(2) && ! target->is_busy())
      #   - target->start_busy(1);
      #   - target->start_busy(4 + random(skill / 30));
      #   - me->start_busy(3 + random(2));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // po.c 破字诀
      # 
      # #include <ansi.h>
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         string msg;
      #         object weapon, weapon2;
      #         int n;
      #         int skill, skill2, ap, dp;
      #         string type;
      # 
      #         if (! target)
      #         {
      #                 me->clean_up_enemy();
      #                 target = me->select_opponent();
      #         }
      # 
      #         skill = me->query_skill("never-defeated", 1);
      # 
      #         skill2 = me->query_skill("martial-cognize", 1);
      # 
      #         if (! me->is_fighting(target))
      #                 return notify_fail("破字诀只能对战斗中的对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon")))
      #                 return notify_fail("你必须手持兵刃才能施展破字诀！\n");
      # 
      #         type = weapon->query("skill_type");
      #         if (me->query_skill(type, 1) < 150)
      #                 return notify_fail("你的" + to_chinese(type) + "水平有限，无法施展破字诀！\n");
      # 
      #         if (me->query_skill_mapped(type) != "never-defeated")
      #                 return notify_fail("你没有激发不败神功，无法施展破字诀！\n");
      # 
      #         if (skill < 100)
      #                 return notify_fail("你的不败神功等级不够，无法施展破字诀！\n");
      # 
      #         if (me->query("neili") < 150)
      #                 return notify_fail("你现在真气不够！\n");
      # 
      #        if (! living(target))
      #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         me->add("neili", -100);
      # 
      #         ap = skill * 3 / 2 + skill2 * 3 / 2;
      #         dp = target->query_skill("parry") +
      #              target->query_skill("martial-cognize", 1);
      # 
      #         msg = HIC "$N" HIC "手中" + weapon->name() +
      #               HIC "一抖，犹如夜雨流星，铺天盖地的攻向$n"
      #               HIC "，没有半点规矩可循。\n" NOR;
      #         if (ap / 2 + random(ap * 2) > dp)
      #         {
      #                 n = 4 + random(4);
      #                 if (ap / 2 + random(ap) > dp)
      #                 {
      #                         msg += HIY "$n" HIY "见来招即巧又拙，不同于人间"
      #                                "任何招式，不禁大为慌乱，一时破绽迭出，$N"
      #                                HIY "见状连出" + chinese_number(n) + "招！\n" NOR;
      #                         message_combatd(msg, me, target);
      #                         me->start_busy(1 + random(n));
      #                         while (n-- && me->is_fighting(target))
      #                         {
      #                                 if (random(2) && ! target->is_busy())
      #                     target->start_busy(1);
      #                                 COMBAT_D->do_attack(me, target, weapon, 0);
      #                         }
      # 
      #                         weapon2 = target->query_temp("weapon");
      #                         if (weapon2 && random(ap) / 2 > dp && weapon2->query("type") != "pin")
      #                         {
      #                                 msg = HIW "$n" HIW "觉得眼前眼花缭乱，手中的" + weapon2->name() +
      #                                       HIW "一时竟然拿捏不住，脱手而出！\n" NOR;
      #                                 weapon2->move(environment(me));
      #                         } else
      #                         {
      #                                 msg = HIY "$n竭力抵挡，一时间再也无力反击。\n" NOR;
      #                         }
      # 
      #                         if (! me->is_fighting(target))
      #                                 // Don't show the message
      #                                 return 1;
      #                 } else
      #                 {
      #                         msg += HIY "$n" HIY "只办了个勉力遮挡，全然无法反击。\n" NOR;
      #                         target->start_busy(4 + random(skill / 30));
      #                 }
      #         } else
      #         {
      #                 msg += HIC "不过$n" HIC "一丝不苟，严守门户，没有露出半点破绽。\n" NOR;
      #                 me->start_busy(3 + random(2));
      #         }
      # 
      #         message_combatd(msg, me, target);
      #         return 1;
      # }
end
