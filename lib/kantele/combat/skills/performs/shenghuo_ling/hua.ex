defmodule Kantele.Combat.Skills.Performs.ShenghuoLing.Hua do
  @moduledoc """
  perform「光华令」（source shenghuo-ling/hua.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "sword"}, {"dp", "parry"}, {"skill", "shenghuo-ling"}], "level_gates": [], "map_gates": [], "prepared_gates": [], "resource_gates": [{"max_neili", "1500"}, {"neili", "340"}], "var_gates": [{"skill", "140"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的兵器不对，不能使用圣火令法之", "你的圣火令法等级不够, 不能使用圣火令法之", "你的内力修为不足，不能使用圣火令法之", "你的内力不够，不能使用圣火令法之", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("sword") + me->query_skill("force")", "dp_formula": "target->query_skill("parry") + target->query_skill("force")"}, "color_codes": ["CYN", "HIR", "HIW", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "$N" HIY "猛吸一口气，使出圣火令法之「" HIW "光华令" HIY "」，手中"
      #                 + weapon->name() + NOR + HIY "御驾如飞，幻出无数道金"
      #                 "芒，将$n" HIY "笼罩起来！\n" NOR", "= CYN "可是$n" CYN "看准$N" CYN "的破绽，猛地向"
      #                          "前一跃，跳出了$N" CYN "的攻击范围。\n"NOR"], "success": ["= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 80,
      #                          HIR "$n" HIR "只觉万道金芒铺天盖地席卷而来，"
      #                          "完全无法阻挡。顿时只感全身几处刺痛，鲜血飞"
      #                          "溅而出！\n" NOR)"]}, "damage_formula": %{"formula": "ap + random(ap / 2)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-150"}, {"neili", "-300"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-150"}, {"neili", "-300"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(4);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(4);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define GUANG "「" HIY "光华令" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         object weapon;
      #         int damage, skill, ap, dp;
      #         string msg;
      # 
      #         if (userp(me) && ! me->query("can_perform/shenghuo-ling/hua"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         skill = me->query_skill("shenghuo-ling",1);
      # 
      #         if (! (me->is_fighting()))
      #                 return notify_fail(GUANG "只能对战斗中的对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon")) ||
      #             (string)weapon->query("skill_type") != "sword")
      #                 return notify_fail("你使用的兵器不对，不能使用圣火令法之" GUANG "。\n");
      # 
      #         if (skill < 140)
      #                 return notify_fail("你的圣火令法等级不够, 不能使用圣火令法之" GUANG "。\n");
      # 
      #         if (me->query("max_neili") < 1500)
      #                 return notify_fail("你的内力修为不足，不能使用圣火令法之" GUANG "。\n");
      # 
      #         if (me->query("neili") < 340)
      #                 return notify_fail("你的内力不够，不能使用圣火令法之" GUANG "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIY "$N" HIY "猛吸一口气，使出圣火令法之「" HIW "光华令" HIY "」，手中"
      #               + weapon->name() + NOR + HIY "御驾如飞，幻出无数道金"
      #               "芒，将$n" HIY "笼罩起来！\n" NOR;
      # 
      #         ap = me->query_skill("sword") + me->query_skill("force");
      #         dp = target->query_skill("parry") + target->query_skill("force");
      # 
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 damage = ap + random(ap / 2);
      # 
      #                 me->add("neili", -300);
      #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 80,
      #                        HIR "$n" HIR "只觉万道金芒铺天盖地席卷而来，"
      #                        "完全无法阻挡。顿时只感全身几处刺痛，鲜血飞"
      #                        "溅而出！\n" NOR);
      # 
      #                 me->start_busy(2);
      #         } else
      #         {
      #                 msg += CYN "可是$n" CYN "看准$N" CYN "的破绽，猛地向"
      #                        "前一跃，跳出了$N" CYN "的攻击范围。\n"NOR;
      #                 me->add("neili", -150);
      #                 me->start_busy(4);
      #         }
      #         message_combatd(msg, me, target);
      #         return 1;
      # }
end
