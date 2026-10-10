defmodule Kantele.Combat.Skills.Performs.QuanzhenJian.Hua do
  @moduledoc """
  perform「一气化三清」（source quanzhen-jian/hua.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "xiantian-gong"}, {"count", "xiantian-gong"}, {"dp", "force"}], "level_gates": [{"quanzhen-jian", "200"}, {"xiantian-gong", "100"}], "map_gates": [{"force", "xiantian-gong"}, {"sword", "quanzhen-jian"}], "prepared_gates": [], "resource_gates": [{"max_neili", "4500"}, {"neili", "500"}], "var_gates": [{"i", "3"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你所使用的武器不对，难以施展", "你全真剑法不够娴熟，难以施展", "你的先天功不够娴熟，难以施展", "你没有激发全真剑法，难以施展", "你没有激发先天功，难以施展", "你的内力修为不够，难以施展", "你现在的真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("xiantian-gong", 1) + me->query_skill("sword")", "dp_formula": "target->query_skill("force") + target->query_skill("parry", 1) * 2 / 3"}, "color_codes": ["CYN", "HIM", "HIR", "HIW", "HIY", "NOR"], "combat_exp_formulas": [{"lvl", "to_int(pow(to_float(me->query("combat_exp") * 10), 1.0 / 3))"}], "combat_messages": %{"fail": [], "other": ["HIW "$N" HIW "一声长吟，将内力全然运到剑上，" + weapon->name() +
      #                 HIW "剑脊顿时" HIM "紫芒" HIW "闪耀，化作数道剑气劲逼$n"
      #                 HIW "。\n" NOR", "= CYN "可是$n" CYN "看破了$N" CYN "的企图，斜跃避开。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 100,
      #                                              HIR "顿时只听$n" HIR "一声惨叫，剑气及"
      #                                              "身，身上接连射出数道血柱。\n" NOR)"]}, "damage_formula": %{"formula": "ap / 2 + random(ap)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-200"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-200"}], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["me->start_busy(3);", "me->start_busy(2);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3);
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
      # #define HUA "「" HIW "一气化三清" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         object weapon;
      #         string msg;
      #         int ap, dp, damage;
      #         int i, count;
      # 
      #         float improve;
      #         int lvl, m, n;
      #         string martial;
      #         string *ks;
      #         martial = "sword";
      # 
      #         if (userp(me) && ! me->query("can_perform/quanzhen-jian/hua"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(HUA "只能对战斗中的对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon")) ||
      #             (string)weapon->query("skill_type") != "sword")
      #                 return notify_fail("你所使用的武器不对，难以施展" HUA "。\n");
      # 
      #         if ((int)me->query_skill("quanzhen-jian", 1) < 200)
      #                 return notify_fail("你全真剑法不够娴熟，难以施展" HUA "。\n");
      # 
      #         if ((int)me->query_skill("xiantian-gong", 1) < 100)
      #                 return notify_fail("你的先天功不够娴熟，难以施展" HUA "。\n");
      # 
      #         if (me->query_skill_mapped("sword") != "quanzhen-jian")
      #                 return notify_fail("你没有激发全真剑法，难以施展" HUA "。\n");
      # 
      #         if (me->query_skill_mapped("force") != "xiantian-gong")
      #                 return notify_fail("你没有激发先天功，难以施展" HUA "。\n");
      # 
      #         if ((int)me->query("max_neili") < 4500)
      #                 return notify_fail("你的内力修为不够，难以施展" HUA "。\n");
      # 
      #         if ((int)me->query("neili") < 500)
      #                 return notify_fail("你现在的真气不足，难以施展" HUA "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIW "$N" HIW "一声长吟，将内力全然运到剑上，" + weapon->name() +
      #               HIW "剑脊顿时" HIM "紫芒" HIW "闪耀，化作数道剑气劲逼$n"
      #               HIW "。\n" NOR;
      # 
      #         lvl = to_int(pow(to_float(me->query("combat_exp") * 10), 1.0 / 3));
      #         lvl = lvl * 4 / 5;
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
      #         improve = improve * 4 / 100 / lvl;
      # 
      #         ap = me->query_skill("xiantian-gong", 1) + me->query_skill("sword");
      #         dp = target->query_skill("force") + target->query_skill("parry", 1) * 2 / 3;
      # 
      #         ap += ap * improve;
      # 
      #         me->start_busy(3);
      #         me->add("neili", -200);
      # 
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 damage = ap / 2 + random(ap);
      #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 100,
      #                                            HIR "顿时只听$n" HIR "一声惨叫，剑气及"
      #                                            "身，身上接连射出数道血柱。\n" NOR);
      #                 message_combatd(msg, me, target);
      # 
      #                 if (ap / 2 + random(ap) > dp)
      #                 {
      #                         count = me->query_skill("xiantian-gong", 1) / 2;
      #                         me->add_temp("apply/attack", count);
      #                         message_combatd(HIY "$N" HIY "见$n" HIY "在这一击之下破"
      #                                         "绽迭出，顿时身形前跃，唰唰唰又是三剑。"
      #                                         "\n" NOR, me, target);
      # 
      #                 for (i = 0; i < 3; i++)
      #                 {
      #                         if (! me->is_fighting(target))
      #                                 break;
      #                         COMBAT_D->do_attack(me, target, weapon, 0);
      #                 }
      #                         me->add_temp("apply/attack", -count);
      #                 }
      #         } else
      #         {
      #                 me->start_busy(2);
      #                 msg += CYN "可是$n" CYN "看破了$N" CYN "的企图，斜跃避开。\n" NOR;
      #                 message_combatd(msg, me, target);
      #         }
      # 
      #         return 1;
      # }
end
