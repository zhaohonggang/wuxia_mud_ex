defmodule Kantele.Combat.Skills.Performs.MiaojiaJian.Gan do
  @moduledoc """
  perform「流星赶月」（source miaojia-jian/gan.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "sword"}, {"dp", "dodge"}], "level_gates": [{"force", "280"}, {"miaojia-jian", "200"}, {"miaojia-jian", "260"}], "map_gates": [{"sword", "miaojia-jian"}], "prepared_gates": [], "resource_gates": [{"max_neili", "3000"}, {"neili", "600"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你苗家剑法不够娴熟，难以施展", "你的内功火候不够，难以施展", "你的内力修为不够，难以施展", "你现在真气不够，难以施展", "你没有激发苗家剑法，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("sword")", "dp_formula": "target->query_skill("dodge")"}, "color_codes": ["HIC", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "$N" HIY "凝聚内力，手中" + wn + HIY "迸出万道光华，蓦然间破空"
      #                 "声骤响，" + wn + HIY "竟离手射出，流星般向$n" HIY "奔去！\n" NOR", "= HIC "$n" HIC "见" + wn + HIC "来势汹涌，心知绝"
      #                          "不可挡，当即向后横移数尺，终于躲闪开来。\n" NOR", "= HIY "只见" + wn + HIY "余势不尽，又向前飞出数"
      #                          "丈，方才没入土中。\n" NOR", "= HIY "然而$N" HIY "身形一展，登时跃出数丈，掌"
      #                          "出如风，将射出的" + wn + HIY "又抄回手中。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 80,
      #                                              HIR "$n" HIR "顿时大惊失色，只觉胸口处"
      #                                              "一凉，那柄" + wn + HIR "竟然已经穿胸透"
      #                                              "过，带出一蓬血雨！\n" NOR)"]}, "damage_formula": %{"formula": "ap / 2 + random(ap)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-500"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-500"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(3);", "me->start_busy(4);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3);
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
      # #define GAN "「" HIY "流星赶月" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         int damage;
      #         string msg;
      #         object weapon;
      #         int ap, dp, wn;
      # 
      #         if (userp(me) && ! me->query("can_perform/miaojia-jian/gan"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(GAN "只能在战斗中对对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon")) ||
      #             (string)weapon->query("skill_type") != "sword")
      #                 return notify_fail("你使用的武器不对，难以施展" GAN "。\n");
      # 
      #         if ((int)me->query_skill("miaojia-jian", 1) < 200)
      #                 return notify_fail("你苗家剑法不够娴熟，难以施展" GAN "。\n");
      # 
      #         if ((int)me->query_skill("force") < 280 )
      #                 return notify_fail("你的内功火候不够，难以施展" GAN "。\n");
      # 
      #         if ((int)me->query("max_neili") < 3000)
      #                 return notify_fail("你的内力修为不够，难以施展" GAN "。\n");
      # 
      #         if ((int)me->query("neili") < 600)
      #                 return notify_fail("你现在真气不够，难以施展" GAN "。\n");
      # 
      #         if (me->query_skill_mapped("sword") != "miaojia-jian")
      #                 return notify_fail("你没有激发苗家剑法，难以施展" GAN "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         wn = weapon->name();
      # 
      #         msg = HIY "$N" HIY "凝聚内力，手中" + wn + HIY "迸出万道光华，蓦然间破空"
      #               "声骤响，" + wn + HIY "竟离手射出，流星般向$n" HIY "奔去！\n" NOR;
      # 
      #         ap = me->query_skill("sword");
      #         dp = target->query_skill("dodge");
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 me->start_busy(3);
      #                 damage = ap / 2 + random(ap);
      #                 damage += random(damage);
      #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 80,
      #                                            HIR "$n" HIR "顿时大惊失色，只觉胸口处"
      #                                            "一凉，那柄" + wn + HIR "竟然已经穿胸透"
      #                                            "过，带出一蓬血雨！\n" NOR);
      #                 me->add("neili", -500);
      #         } else
      #         {
      #                 me->start_busy(4);
      #                 msg += HIC "$n" HIC "见" + wn + HIC "来势汹涌，心知绝"
      #                        "不可挡，当即向后横移数尺，终于躲闪开来。\n" NOR;
      #                 me->add("neili", -500);
      #         }
      # 
      #         if (userp(me) && (int)me->query_skill("miaojia-jian", 1) < 260)
      #         {
      #                 msg += HIY "只见" + wn + HIY "余势不尽，又向前飞出数"
      #                        "丈，方才没入土中。\n" NOR;
      #             weapon->move(environment(me));
      #     } else
      #                 msg += HIY "然而$N" HIY "身形一展，登时跃出数丈，掌"
      #                        "出如风，将射出的" + wn + HIY "又抄回手中。\n" NOR;
      # 
      #         message_combatd(msg, me, target);
      #         return 1;
      # }
end
