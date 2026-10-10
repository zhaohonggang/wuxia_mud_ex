defmodule Kantele.Combat.Skills.Performs.TianzhuJian.Suo do
  @moduledoc """
  perform「烟云锁身」（source tianzhu-jian/suo.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "tianzhu-jian"}, {"dp", "parry"}], "level_gates": [{"dodge", "150"}, {"tianzhu-jian", "120"}], "map_gates": [{"sword", "tianzhu-jian"}], "prepared_gates": [], "resource_gates": [{"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你天柱剑法不够娴熟，难以施展", "你没有激发天柱剑法，难以施展", "你的轻功修为不够，难以施展", "你现在的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("tianzhu-jian", 1)", "dp_formula": "target->query_skill("parry", 1)"}, "color_codes": ["CYN", "HIC", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "\n$N" HIW "剑法陡然变快，施展出「烟云锁身剑」，手中" +
      #                         wp + HIW "幻作一道白芒，撩向$n" HIW "所持的" + wp2 + HIW
      #                         "。" NOR", "= CYN "可是$n" CYN "看破$N" CYN "剑法中的虚招，镇"
      #                                  "定自如，从容应对。\n" NOR", "HIC "\n$N" HIC "剑法陡然变快，施展出「" HIW "烟云锁身剑"
      #                         HIC "」，手中" + wp + HIC "剑光夺目，欲将$n" HIC "笼罩在"
      #                         "剑光之中。" NOR", "= CYN "\n可是$n" CYN "看破$N" CYN "剑法中的虚招，镇"
      #                                  "定自如，从容应对。" NOR"], "success": ["HIR "$n" HIR "只见眼前白芒暴涨，登时右手一轻，"
      #                                 + wp2 + HIR "竟脱手飞出。\n" NOR", "= HIR "\n$n" HIR "惊慌不定，顿时乱了阵脚，竟被困于$N"
      #                                  HIR "的剑光当中。" NOR"]}, "resource_adds": [{"neili", "-100"}, {"neili", "-200"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-200"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (target->is_busy())", "me->start_busy(2);", "target->start_busy(3);", "me->start_busy(1);", "target->start_busy(ap / 25 + 1);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (target->is_busy())
      #   - me->start_busy(2);
      #   - target->start_busy(3);
      #   - me->start_busy(1);
      #   - target->start_busy(ap / 25 + 1);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define SUO "「" HIW "烟云锁身" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         string msg, wp, wp2;
      #         object weapon, weapon2;
      #         int ap, dp;
      # 
      #         if (userp(me) && ! me->query("can_perform/tianzhu-jian/suo"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(SUO "只能对战斗中的对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon")) ||
      #             (string)weapon->query("skill_type") != "sword")
      #         return notify_fail("你使用的武器不对，难以施展" SUO "。\n");
      # 
      #         if (target->is_busy())
      #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
      # 
      #         if ((int)me->query_skill("tianzhu-jian", 1) < 120)
      #                 return notify_fail("你天柱剑法不够娴熟，难以施展" SUO "。\n");
      # 
      #         if (me->query_skill_mapped("sword") != "tianzhu-jian")
      #                 return notify_fail("你没有激发天柱剑法，难以施展" SUO "。\n");
      # 
      #         if (me->query_skill("dodge") < 150)
      #                 return notify_fail("你的轻功修为不够，难以施展" SUO "。\n");
      # 
      #         if ((int)me->query("neili") < 200)
      #                 return notify_fail("你现在的真气不够，难以施展" SUO "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         wp = weapon->name();
      #         ap = me->query_skill("tianzhu-jian", 1);
      #         dp = target->query_skill("parry", 1);
      # 
      #         if (me->query("max_neili") > target->query("max_neili") * 3 / 2
      #            && objectp(weapon2 = target->query_temp("weapon")))
      #         {
      #                 wp2 = weapon2->name();
      # 
      #         msg = HIW "\n$N" HIW "剑法陡然变快，施展出「烟云锁身剑」，手中" +
      #                       wp + HIW "幻作一道白芒，撩向$n" HIW "所持的" + wp2 + HIW
      #                       "。" NOR;
      # 
      #                 message_sort(msg, me, target);
      # 
      #                me->start_busy(2);
      #                me->add("neili", -200);
      # 
      #             if (random(ap) > dp / 2)
      #             {
      #                     msg = HIR "$n" HIR "只见眼前白芒暴涨，登时右手一轻，"
      #                               + wp2 + HIR "竟脱手飞出。\n" NOR;
      # 
      #                     target->start_busy(3);
      #                         weapon2->move(environment(target));
      #             } else
      #         {
      #                 msg += CYN "可是$n" CYN "看破$N" CYN "剑法中的虚招，镇"
      #                                "定自如，从容应对。\n" NOR;
      #             }
      #     } else
      #     {
      #         msg = HIC "\n$N" HIC "剑法陡然变快，施展出「" HIW "烟云锁身剑"
      #                       HIC "」，手中" + wp + HIC "剑光夺目，欲将$n" HIC "笼罩在"
      #                       "剑光之中。" NOR;
      # 
      #                me->start_busy(1);
      #             me->add("neili", -100);
      # 
      #             if (random(ap) > dp / 2)
      #             {
      #                     msg += HIR "\n$n" HIR "惊慌不定，顿时乱了阵脚，竟被困于$N"
      #                                HIR "的剑光当中。" NOR;
      # 
      #                         target->start_busy(ap / 25 + 1);
      #             } else
      #         {
      #                 msg += CYN "\n可是$n" CYN "看破$N" CYN "剑法中的虚招，镇"
      #                                "定自如，从容应对。" NOR;
      #             }
      #     }
      #         message_combatd(msg, me, target);
      #         return 1;
      # }
end
