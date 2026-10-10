defmodule Kantele.Combat.Skills.Performs.XueshanDao.Kai do
  @moduledoc """
  perform「冰河开封」（source xueshan-dao/kai.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "blade"}, {"dp", "parry"}], "level_gates": [{"force", "100"}, {"xueshan-dao", "80"}], "map_gates": [{"blade", "xueshan-dao"}], "prepared_gates": [], "resource_gates": [{"neili", "150"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你的内功火候不够，难以施展", "你的雪山刀法还不到家，难以施展", "你没有激发雪山刀法，难以施展", "你的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("blade")", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["CYN", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "只见$N" HIW "手中的" + weapon->name() +  HIW "豪光绽放，嗡"
      #                 "嗡作响，刀锋顿时迸出一道寒芒向$n" HIW "砍落！\n" NOR", "= CYN "可是$p" CYN "凝神聚气，护住门户，$P"
      #                          CYN "刀芒虽然凌厉，始终奈何不得。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 35,
      #                                              HIR "$n" HIR "招架不及，顿时被$N" HIR
      #                                              "凌厉的刀芒划中要害，鲜血狂溅而出！\n" NOR)"]}, "damage_formula": %{"formula": "ap / 2 + random(ap / 2)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}, {"neili", "-50"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}, "weapon_type": "blade"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-50"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
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
      # #define KAI "「" HIW "冰河开封" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #     object weapon;
      #     int damage;
      #     string msg;
      #         int ap, dp;
      # 
      #         if (userp(me) && ! me->query("can_perform/xueshan-dao/kai"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target)
      #         {
      #                 me->clean_up_enemy();
      #                 target = me->select_opponent();
      #         }
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(KAI "只能对战斗中的对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon")) ||
      #             (string)weapon->query("skill_type") != "blade")
      #                 return notify_fail("你使用的武器不对，难以施展" KAI "。\n");
      # 
      #         if ((int)me->query_skill("force") < 100)
      #                 return notify_fail("你的内功火候不够，难以施展" KAI "。\n");
      # 
      #         if ((int)me->query_skill("xueshan-dao", 1) < 80)
      #                 return notify_fail("你的雪山刀法还不到家，难以施展" KAI "。\n");
      # 
      #         if (me->query_skill_mapped("blade") != "xueshan-dao")
      #                 return notify_fail("你没有激发雪山刀法，难以施展" KAI "。\n");
      # 
      #         if ((int)me->query("neili") < 150)
      #                 return notify_fail("你的真气不够，难以施展" KAI "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #     msg = HIW "只见$N" HIW "手中的" + weapon->name() +  HIW "豪光绽放，嗡"
      #               "嗡作响，刀锋顿时迸出一道寒芒向$n" HIW "砍落！\n" NOR;
      # 
      #         ap = me->query_skill("blade");
      #         dp = target->query_skill("parry");
      # 
      #         if (ap / 2 + random(ap) > dp)
      #     {
      #         damage = ap / 2 + random(ap / 2);
      #                 me->add("neili", -100);
      #         msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 35,
      #                                            HIR "$n" HIR "招架不及，顿时被$N" HIR
      #                                            "凌厉的刀芒划中要害，鲜血狂溅而出！\n" NOR);
      #         me->start_busy(2);
      #     } else
      #     {
      #         msg += CYN "可是$p" CYN "凝神聚气，护住门户，$P"
      #                        CYN "刀芒虽然凌厉，始终奈何不得。\n" NOR;
      #                 me->add("neili", -50);
      #         me->start_busy(3);
      #     }
      #     message_combatd(msg, me, target);
      # 
      #     return 1;
      # }
end
