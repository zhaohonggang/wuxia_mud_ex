defmodule Kantele.Combat.Skills.Performs.XueshanJian.Hui do
  @moduledoc """
  perform「风回雪舞」（source xueshan-jian/hui.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "xueshan-jian"}, {"dp", "parry"}], "level_gates": [{"force", "50"}, {"xueshan-jian", "30"}], "map_gates": [{"sword", "xueshan-jian"}], "prepared_gates": [], "resource_gates": [{"neili", "50"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你的内功的修为不够，难以施展", "你的雪山剑法修为不够，难以施展", "你的真气不够，难以施展", "你没有激发雪山剑法，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("xueshan-jian", 1)", "dp_formula": "target->query_skill("parry", 1)"}, "color_codes": ["CYN", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "$N" HIW "回剑旋舞，一式「风回雪舞」施出，剑势连绵不绝，呼"
      #                 "啸而至，欲图将$n" HIW "缠裹其中。\n" NOR", "= CYN "可是$p" CYN "看破了$P" CYN "的企图，镇"
      #                          "定逾恒，全神应对自如。\n" NOR"], "success": ["= HIR "$n" HIR "只觉重重剑影铺天盖地向自己撒"
      #                          "来，顿被攻了个手忙脚乱，不知如何应对。\n"
      #                          NOR"]}, "resource_adds": [{"neili", "-30"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-30"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (target->is_busy())", "target->start_busy(ap / 16 + 2);", "me->start_busy(2);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (target->is_busy())
      #   - target->start_busy(ap / 16 + 2);
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
      # #define HUI "「" HIW "风回雪舞" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         object weapon;
      #         string msg;
      #         int ap, dp;
      # //      int count;
      # //      int i, attack_time;
      # 
      #         if (! target)
      #         {
      #                 me->clean_up_enemy();
      #                 target = me->select_opponent();
      #         }
      # 
      #         if (userp(me) && ! me->query("can_perform/xueshan-jian/hui"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(HUI "只能对战斗中的对手使用。\n");
      # 
      #         if (target->is_busy())
      #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon")) ||
      #               (string)weapon->query("skill_type") != "sword")
      #                 return notify_fail("你使用的武器不对，难以施展" HUI "。\n");
      # 
      #         if (me->query_skill("force") < 50)
      #                 return notify_fail("你的内功的修为不够，难以施展" HUI "。\n");
      # 
      #         if (me->query_skill("xueshan-jian", 1) < 30)
      #                 return notify_fail("你的雪山剑法修为不够，难以施展" HUI "。\n");
      # 
      #         if (me->query("neili") < 50)
      #                 return notify_fail("你的真气不够，难以施展" HUI "。\n");
      # 
      #         if (me->query_skill_mapped("sword") != "xueshan-jian")
      #                 return notify_fail("你没有激发雪山剑法，难以施展" HUI "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         ap = me->query_skill("xueshan-jian", 1);
      #         dp = target->query_skill("parry", 1);
      # 
      #         msg = HIW "$N" HIW "回剑旋舞，一式「风回雪舞」施出，剑势连绵不绝，呼"
      #               "啸而至，欲图将$n" HIW "缠裹其中。\n" NOR;
      # 
      #         me->add("neili", -30);
      #         if (random(ap) > dp / 2)
      #         {
      #                 msg += HIR "$n" HIR "只觉重重剑影铺天盖地向自己撒"
      #                        "来，顿被攻了个手忙脚乱，不知如何应对。\n"
      #                        NOR;
      #                 target->start_busy(ap / 16 + 2);
      #         } else
      #         {
      #                 msg += CYN "可是$p" CYN "看破了$P" CYN "的企图，镇"
      #                        "定逾恒，全神应对自如。\n" NOR;
      #                 me->start_busy(2);
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
end
