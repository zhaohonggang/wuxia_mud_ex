defmodule Kantele.Combat.Skills.Performs.LiangyiJian.Ren do
  @moduledoc """
  perform「天地同仁」（source liangyi-jian/ren.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "sword"}, {"dp", "parry"}], "level_gates": [{"liangyi-jian", "120"}], "map_gates": [{"sword", "liangyi-jian"}], "prepared_gates": [], "resource_gates": [{"max_neili", "1500"}, {"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你两仪剑法不够娴熟，难以施展", "你的内力修为不足，难以施展", "你没有激发两仪剑法，难以施展", "你现在真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("sword")", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["CYN", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "$N" HIW "手中" + weapon->name() + HIW"剑芒跃动，剑光暴长，剑尖颤动似乎分左右刺向$n"
      #                 HIW "，$n" HIW "看到剑\n光偏左，疾侧身右转，但只这一刹，剑光刹时袭"
      #                 "向右首！\n"", "= CYN "可是$p" CYN "轻轻一笑，侧身右转，躲开了$P"
      #                          CYN "左转的剑式，毫发未伤。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,
      #                                              HIR "$n" HIR "疾忙左转，却发现$N" HIR
      #                                              "的" + weapon->name() + HIR "疾往左转"
      #                                              "，登时穿胸而过，血如泉涌。\n" NOR)"]}, "damage_formula": %{"formula": "ap * 4 / 3"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}, {"neili", "-180"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-180"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define REN "「" HIW "天地同仁" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         int ap, dp, damage;
      #         string msg;
      #         object weapon;
      # 
      # //冲虚是武当追杀npc，所以不实际增加冲虚了，两仪剑绝招改为自动可用。
      #         //if (userp(me) && ! me->query("can_perform/liangyi-jian/ren"))
      #        //         return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(REN "只能对战斗中的对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon")) ||
      #             (string)weapon->query("skill_type") != "sword")
      #                 return notify_fail("你使用的武器不对，难以施展" REN "。\n");
      # 
      #         if ((int)me->query_skill("liangyi-jian", 1) < 120)
      #                 return notify_fail("你两仪剑法不够娴熟，难以施展" REN "。\n");
      # 
      #         if ((int)me->query("max_neili") < 1500)
      #                 return notify_fail("你的内力修为不足，难以施展" REN "。\n");
      # 
      #         if (me->query_skill_mapped("sword") != "liangyi-jian")
      #                 return notify_fail("你没有激发两仪剑法，难以施展" REN "。\n");
      # 
      #         if ((int)me->query("neili") < 200)
      #                 return notify_fail("你现在真气不够，难以施展" REN "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIW "$N" HIW "手中" + weapon->name() + HIW"剑芒跃动，剑光暴长，剑尖颤动似乎分左右刺向$n"
      #               HIW "，$n" HIW "看到剑\n光偏左，疾侧身右转，但只这一刹，剑光刹时袭"
      #               "向右首！\n";
      # 
      #         ap = me->query_skill("sword");
      #         dp = target->query_skill("parry");
      # 
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 me->start_busy(2);
      #                 damage = ap * 4 / 3;
      #                 damage = damage / 2 + random(damage * 2 / 3);
      # 
      #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,
      #                                            HIR "$n" HIR "疾忙左转，却发现$N" HIR
      #                                            "的" + weapon->name() + HIR "疾往左转"
      #                                            "，登时穿胸而过，血如泉涌。\n" NOR);
      #                 me->add("neili", -180);
      #         } else
      #         {
      #                   me->add("neili", -100);
      #                 me->start_busy(3);
      #                 msg += CYN "可是$p" CYN "轻轻一笑，侧身右转，躲开了$P"
      #                        CYN "左转的剑式，毫发未伤。\n" NOR;
      #         }
      #         message_combatd(msg, me, target);
      #         return 1;
      # }
end
