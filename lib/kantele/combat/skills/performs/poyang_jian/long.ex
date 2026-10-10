defmodule Kantele.Combat.Skills.Performs.PoyangJian.Long do
  @moduledoc """
  perform「天外玉龙」（source poyang-jian/long.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "sword"}, {"dp", "parry"}], "level_gates": [{"dodge", "200"}, {"force", "200"}, {"poyang-jian", "180"}], "map_gates": [{"sword", "poyang-jian"}], "prepared_gates": [], "resource_gates": [{"max_neili", "2700"}, {"neili", "350"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你的内功的修为不够，难以施展", "你的破阳冷光剑修为不够，难以施展", "你的轻功火候不够，难以施展", "你的内力修为不足，难以施展", "你的真气不够，难以施展", "你没有激发破阳冷光剑，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("sword")", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["CYN", "HIC", "HIR", "HIW", "HIY", "NOR"], "combat_exp_formulas": [{"lvls", "to_int(pow(to_float(me->query("combat_exp") * 10), 1.0 / 3))"}], "combat_messages": %{"fail": [], "other": ["HIY "\n只见$N" HIY "手中" + weapon->name() + HIY
      #                         "横扫而出，施出绝招「" HIC "天外玉龙" HIY "」，"
      #                         "剑势纵横，犹如一条长龙蜿蜒而出，刺向$n\n" HIY "。" NOR", "HIW "\n但见$N" HIW "手中" + weapon->name() + HIW
      #                         "自半空中横过，剑身似曲似直，便如一件活物一般，正"
      #                         "是破阳冷光剑的精髓「" HIY "天外玉龙" HIW "」，一"
      #                         "柄死剑被$N" HIW "使得如灵蛇，如神龙，猛然剑刺向$n\n"
      #                         HIW "。" NOR", "CYN "可却见" CYN "$n" CYN "猛的拔地而起，避开了"
      #                         CYN "$N" CYN "来势凶猛的一招。\n" NOR"], "success": ["COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, hit_point,
      #                                              HIR "$n" HIR "见此招来势凶猛， 阻挡不"
      #                                              "及， 顿时被" + weapon->name() + HIR
      #                                              "所伤，苦不堪言。\n" NOR)"]}, "damage_formula": %{"formula": "ap / 2 + random(ap)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-150"}, {"neili", "-neili"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-150"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(time);", "me->start_busy(1 + random(2));"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(time);
      #   - me->start_busy(1 + random(2));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # 
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define LONG "「" HIC "天外玉龙" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         object weapon;
      #         string msg;
      #         int ap, dp;
      #         int damage;
      #         int neili, hit_point, time;
      # 
      #         float improve;
      #         int lvls, m, n;
      #         string martial;
      #         string *ks;
      #         martial = "sword";
      # 
      #         if (userp(me) && ! me->query("can_perform/poyang-jian/long"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(LONG "只能对战斗中的对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon"))
      #            || (string)weapon->query("skill_type") != "sword")
      #                 return notify_fail("你使用的武器不对，难以施展" LONG "。\n");
      # 
      #         if (me->query_skill("force") < 200)
      #                 return notify_fail("你的内功的修为不够，难以施展" LONG "。\n");
      # 
      #         if (me->query_skill("poyang-jian", 1) < 180)
      #                 return notify_fail("你的破阳冷光剑修为不够，难以施展" LONG "。\n");
      # 
      #         if ((int)me->query_skill("dodge") < 200)
      #                 return notify_fail("你的轻功火候不够，难以施展" LONG "。\n");
      # 
      #         if ((int)me->query("max_neili") < 2700)
      #                 return notify_fail("你的内力修为不足，难以施展" LONG "。\n");
      # 
      #         if (me->query("neili") < 350)
      #                 return notify_fail("你的真气不够，难以施展" LONG "。\n");
      # 
      #         if (me->query_skill_mapped("sword") != "poyang-jian")
      #                 return notify_fail("你没有激发破阳冷光剑，难以施展" LONG "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         lvls = to_int(pow(to_float(me->query("combat_exp") * 10), 1.0 / 3));
      #         lvls = lvls * 4 / 5;
      #         ks = keys(me->query_skills(martial));
      #         improve = 0;
      #         n = 0;
      #         //最多给予5个技能的加成
      #         for (m = 0; m < sizeof(ks); m++)
      #         {
      #             if (SKILL_D(ks[m])->valid_enable(martial))
      #             {
      #                 n += 1;
      #                 improve += (int)me->query_skill(ks[m], 1);
      #                 if (n > 4 )
      #                     break;
      #             }
      #         }
      # 
      #         improve = improve * 5 / 100 / lvls;
      # 
      #         if (! me->query("real_perform/poyang-jian/long"))
      #         {
      #                 msg = HIY "\n只见$N" HIY "手中" + weapon->name() + HIY
      #                       "横扫而出，施出绝招「" HIC "天外玉龙" HIY "」，"
      #                       "剑势纵横，犹如一条长龙蜿蜒而出，刺向$n\n" HIY "。" NOR;
      # 
      #                 neili = 220;
      #                 hit_point = 55;
      #                 time = 2 + random(2);
      #         }
      # 
      #         else
      #         {
      #                 msg = HIW "\n但见$N" HIW "手中" + weapon->name() + HIW
      #                       "自半空中横过，剑身似曲似直，便如一件活物一般，正"
      #                       "是破阳冷光剑的精髓「" HIY "天外玉龙" HIW "」，一"
      #                       "柄死剑被$N" HIW "使得如灵蛇，如神龙，猛然剑刺向$n\n"
      #                       HIW "。" NOR;
      # 
      #                 neili = 300;
      #                 hit_point = 80;
      #                 time = 3 + random(4);
      #         }
      #         message_sort(msg, me, target);
      # 
      #         ap = me->query_skill("sword");
      # 
      #         dp = target->query_skill("parry");
      # 
      #         ap += ap * improve;
      # 
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 damage = ap / 2 + random(ap);
      #                 me->add("neili", -neili);
      #                 me->start_busy(time);
      #                 msg = COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, hit_point,
      #                                            HIR "$n" HIR "见此招来势凶猛， 阻挡不"
      #                                            "及， 顿时被" + weapon->name() + HIR
      #                                            "所伤，苦不堪言。\n" NOR);
      #         } else
      #         {
      #                 me->add("neili", -150);
      #                 me->start_busy(1 + random(2));
      #                 msg = CYN "可却见" CYN "$n" CYN "猛的拔地而起，避开了"
      #                       CYN "$N" CYN "来势凶猛的一招。\n" NOR;
      #         }
      #         message_vision(msg, me, target);
      # 
      #         return 1;
      # }
end
