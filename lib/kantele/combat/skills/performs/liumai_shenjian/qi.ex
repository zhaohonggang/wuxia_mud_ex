defmodule Kantele.Combat.Skills.Performs.LiumaiShenjian.Qi do
  @moduledoc """
  perform「无形剑气」（source liumai-shenjian/qi.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "finger"}, {"dp", "force"}], "level_gates": [{"force", "420"}, {"liumai-shenjian", "200"}], "map_gates": [], "prepared_gates": [{"finger", "liumai-shenjian"}], "resource_gates": [{"max_neili", "5000"}, {"neili", "500"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的内功火候不够，使不出", "你的内力修为还不足以使出如此犀利的", "你的真气不够，无法使用", "你的六脉神剑修为有限，无法使用", "你没有准备六脉神剑，无法使用", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("finger")", "dp_formula": "target->query_skill("force")"}, "color_codes": ["CYN", "HIG", "HIR", "NOR"], "combat_messages": %{"fail": ["= CYN "可是$p" CYN "内功颇为深厚，轻轻将这道剑气化解于无形。\n" NOR"], "other": ["HIG "$N" HIG "中指一按，一股凌厉无伦的无形剑气直奔$n" HIG "胸前射去。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 86,
      #                                                      HIR "$n" HIR "只觉得胸前一阵剧痛，鲜血"
      #                                                      "自创口激射而出，眼前顿时一黑！\n" NOR)", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 74,
      #                                                      HIR "$n" HIR "横" + weapon->name() + HIR "试图招架，"
      #                                                      HIR "怎奈这股剑气如此犀利，透过" + weapon->name() +
      #                                                      HIR "直震得$n" HIR "狂吐鲜血，五脏六腑都要翻转过来！\n" NOR)", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 55,
      #                                                      HIR "$n" HIR "横转" + weapon->name() + HIR "，挡在胸"
      #                                                      "前，只听啪啦一声，" + weapon->name() +
      #                                                      HIR "碎成数截，激飞上天！\n$n" HIR "连退"
      #                                                      "几步，“哇”的吐了一口鲜血，脸色变的惨白。\n" NOR)"]}, "damage_formula": %{"formula": "ap + random(ap / 2)"}, "hit_formula": %{"left_side": "ap * 2 / 3 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-400"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_forbidden": ["hammer", "pin"]}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-400"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(3);"], "remote_damage": true, "set_flags": [{"value", "0"}], "temp_set": []}
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // qi.c 无形剑气
      # 
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # inherit F_SSERVER;
      # 
      # #define QI "「" HIG "无形剑气" NOR "」"
      # 
      # int perform(object me, object target)
      # {
      #         object weapon;
      #         int damage;
      #         string msg;
      #         int ap, dp;
      # 
      #         if (! target) target = offensive_target(me);
      # 
      # 
      #         if (userp(me) && ! me->query("can_perform/liumai-shenjian/qi"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(QI "只能对战斗中的对手使用。\n");
      # 
      #         if ((int)me->query_skill("force") < 420)
      #                 return notify_fail("你的内功火候不够，使不出" QI "。\n");
      # 
      #         if (me->query("max_neili") < 5000)
      #                 return notify_fail("你的内力修为还不足以使出如此犀利的" QI "。\n");
      # 
      #         if ((int)me->query("neili") < 500)
      #                 return notify_fail("你的真气不够，无法使用" QI "。\n");
      # 
      #         if (me->query_skill("liumai-shenjian", 1) < 200)
      #                 return notify_fail("你的六脉神剑修为有限，无法使用" QI "！\n");
      # 
      #         if (me->query_skill_prepared("finger") != "liumai-shenjian")
      #                 return notify_fail("你没有准备六脉神剑，无法使用" QI "。\n");
      # 
      #         if (! living(target))
      #                return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIG "$N" HIG "中指一按，一股凌厉无伦的无形剑气直奔$n" HIG "胸前射去。\n" NOR;  
      # 
      #         ap = me->query_skill("finger");
      #         dp = target->query_skill("force");
      #         weapon = target->query_temp("weapon");
      #         me->start_busy(3);
      #         if (ap * 2 / 3 + random(ap) > dp)
      #         { 
      #                 damage = ap + random(ap / 2);
      #                 me->add("neili", -400);
      #                 if (! objectp(weapon) || weapon->query("skill_type") == "pin")
      #                         msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 86,
      #                                                    HIR "$n" HIR "只觉得胸前一阵剧痛，鲜血"
      #                                                    "自创口激射而出，眼前顿时一黑！\n" NOR);
      #                 else
      #                 if (weapon->is_item_make() || weapon->query("damage") > 180 ||
      #                     weapon->query("skill_type") == "hammer")
      #                         msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 74,
      #                                                    HIR "$n" HIR "横" + weapon->name() + HIR "试图招架，"
      #                                                    HIR "怎奈这股剑气如此犀利，透过" + weapon->name() +
      #                                                    HIR "直震得$n" HIR "狂吐鲜血，五脏六腑都要翻转过来！\n" NOR);
      #                 else
      #                 {
      #                         msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 55,
      #                                                    HIR "$n" HIR "横转" + weapon->name() + HIR "，挡在胸"
      #                                                    "前，只听啪啦一声，" + weapon->name() +
      #                                                    HIR "碎成数截，激飞上天！\n$n" HIR "连退"
      #                                                    "几步，“哇”的吐了一口鲜血，脸色变的惨白。\n" NOR);
      #                         weapon->move(environment(me));
      #                         weapon->set("no_wield", weapon->name() + "已经碎掉了，没法装备了。\n");
      #                         weapon->set_name("碎掉的" + weapon->name());
      #                         weapon->set("value", 0);
      #                 }
      #         } else
      #         {
      #                 msg += CYN "可是$p" CYN "内功颇为深厚，轻轻将这道剑气化解于无形。\n" NOR;
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
end
