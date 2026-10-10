defmodule Kantele.Combat.Skills.Performs.ShedaoQigong.Cui do
  @moduledoc """
  perform「cui」（source shedao-qigong/cui.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"dp", "dodge"}, {"fp", "force"}], "level_gates": [{"shedao-qigong", "120"}], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "250"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你现在还不会使用摧心断肠！\n", "「摧心断肠」只能对战斗中的对手使用。\n", "你的蛇岛奇功修为有限，不能使用「摧心断肠」！\n", "你的真气不够，无法运用「摧心断肠」！\n", "你使用的兵器不对，怎么使用「摧心断肠」！\n", "你没有将", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill(skill)", "dp_formula": "target->query_skill("dodge")"}, "color_codes": ["CYN", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "$N" HIW "一声暴喝，双掌一起击出，霎时间飞砂走石，$n"
      #                         HIW "只觉得几乎窒息。\n" NOR", "HIW "$N" HIW "一声暴喝，手中" + weapon->name() +
      #                         HIW "直劈而下，只听呼啸声大作，地上的尘土受内力所激纷纷飞扬而起。\n" NOR", "HIW "$N" HIW "一声暴喝，手中" + weapon->name() +
      #                         HIW "横扫荡出，一时间尘土飞扬，$n"
      #                         HIW "登时觉得呼吸不畅。\n" NOR", "= CYN "可是$n" CYN "内功深厚，奋力接下$N"
      #                          CYN "这一招，丝毫无损。\n" NOR", "= CYN "$n" CYN "哈哈一笑，飘身跃开，让$N"
      #                          CYN "这一招全然落空。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, 60,
      #                                              HIR "$n" HIR "只觉得$N" HIR "内力犹如"
      #                                              "排山倒海一般，怎能抵挡？“哇”的一下吐出一大口鲜血。\n" NOR)"]}, "damage_formula": %{"formula": "50 + ap + random(ap)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": "<", "right_side": "dp"}, "resource_adds": [{"neili", "-200"}, {"neili", "-220"}, {"neili", "-50"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}, "weapon_type": "staff"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-200"}, {"neili", "-220"}, {"neili", "-50"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);", "me->start_busy(2);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(3);
      #   - me->start_busy(2);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // cui.c 摧心断肠
      # 
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         object weapon;
      #         string msg;
      #         string skill;
      #         int ap, fp, dp, damage;
      # 
      #         if (userp(me) && ! me->query("can_perform/shedao-qigong/xian"))
      #                 return notify_fail("你现在还不会使用摧心断肠！\n");
      # 
      #         if (! target)
      #         {
      #                 me->clean_up_enemy();
      #                 target = me->select_opponent();
      #         }
      # 
      #         if (! me->is_fighting(target))
      #                 return notify_fail("「摧心断肠」只能对战斗中的对手使用。\n");
      # 
      #         if (me->query_skill("shedao-qigong", 1) < 120)
      #                 return notify_fail("你的蛇岛奇功修为有限，不能使用「摧心断肠」！\n");
      # 
      #         if (me->query("neili") < 250)
      #                 return notify_fail("你的真气不够，无法运用「摧心断肠」！\n");
      # 
      #         if (objectp(weapon = me->query_temp("weapon")) &&
      #             weapon->query("skill_type") != "staff" &&
      #             weapon->query("skill_type") != "sword")
      #                 return notify_fail("你使用的兵器不对，怎么使用「摧心断肠」！\n");
      # 
      #         if (weapon)
      #                 skill = weapon->query("skill_type");
      #         else
      #                 skill = "unarmed";
      # 
      #         if (me->query_skill_mapped(skill) != "shedao-qigong")
      #                 return notify_fail("你没有将" + (string)to_chinese(skill)[4..<1] +
      #                                    "激发为蛇岛奇功, 不能使用「摧心断肠」！\n");
      # 
      #        if (! living(target))
      #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         switch (skill)
      #         {
      #         case "unarmed":
      #                 msg = HIW "$N" HIW "一声暴喝，双掌一起击出，霎时间飞砂走石，$n"
      #                       HIW "只觉得几乎窒息。\n" NOR;
      #                 break;
      # 
      #         case "sword":
      #                 msg = HIW "$N" HIW "一声暴喝，手中" + weapon->name() +
      #                       HIW "直劈而下，只听呼啸声大作，地上的尘土受内力所激纷纷飞扬而起。\n" NOR;
      #                 break;
      # 
      #         case "staff":
      #                 msg = HIW "$N" HIW "一声暴喝，手中" + weapon->name() +
      #                       HIW "横扫荡出，一时间尘土飞扬，$n"
      #                       HIW "登时觉得呼吸不畅。\n" NOR;
      #                 break;
      #         }
      # 
      #         ap = me->query_skill(skill);
      #         fp = target->query_skill("force");
      #         dp = target->query_skill("dodge");
      #         if (ap / 2 + random(ap) < fp)
      #         {
      #                 me->add("neili", -200);
      #                 msg += CYN "可是$n" CYN "内功深厚，奋力接下$N"
      #                        CYN "这一招，丝毫无损。\n" NOR;
      #                 me->start_busy(2);
      #         } else
      #         if (ap / 2 + random(ap) < dp)
      #         {
      #                 me->add("neili", -50);
      #                 msg += CYN "$n" CYN "哈哈一笑，飘身跃开，让$N"
      #                        CYN "这一招全然落空。\n" NOR;
      #                 me->start_busy(3);
      #         } else
      #         {
      #                 me->add("neili", -220);
      #                 me->start_busy(2);
      #                 damage = 50 + ap + random(ap);
      #                 msg += COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, 60,
      #                                            HIR "$n" HIR "只觉得$N" HIR "内力犹如"
      #                                            "排山倒海一般，怎能抵挡？“哇”的一下吐出一大口鲜血。\n" NOR);
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
end
