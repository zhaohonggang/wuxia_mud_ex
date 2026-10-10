defmodule Kantele.Combat.Skills.Performs.MiaojiaJian.Zhai do
  @moduledoc """
  perform「云边摘月」（source miaojia-jian/zhai.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"level", "miaojia-jian"}], "level_gates": [{"force", "120"}, {"miaojia-jian", "100"}], "map_gates": [{"sword", "miaojia-jian"}], "prepared_gates": [], "resource_gates": [{"max_neili", "800"}, {"neili", "100"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你苗家剑法不够娴熟，难以施展", "你的内功火候不够，难以施展", "你的内力修为不够，难以施展", "你现在真气不够，难以施展", "你没有激发苗家剑法，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["CYN", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "$N" HIW "一声清哮，剑势舒张，吞吐不定，瞬间向$n" HIW "连刺"
      #                 "数剑，企图扰乱$n" HIW "的攻势。\n" NOR", "= CYN "可是$p" CYN "看破了$P" CYN "剑势的来路，"
      #                          "径自出招，丝毫不为所动。\n" NOR"], "success": ["= HIR "结果$p" HIR "只见$P" HIR "剑招精妙，全然"
      #                          "辨不清招中虚实，攻势登时一紧！\n" NOR"]}, "resource_adds": [{"neili", "-30"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-30"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (target->is_busy())", "target->start_busy(level / 18 + 2);", "me->start_busy(2);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (target->is_busy())
      #   - target->start_busy(level / 18 + 2);
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
      # #define ZHAI "「" HIW "云边摘月" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #     object weapon;
      #     int level;
      #     string msg;
      # 
      #         if (userp(me) && ! me->query("can_perform/miaojia-jian/zhai"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(ZHAI "只能对战斗中的对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon")) ||
      #             (string)weapon->query("skill_type") != "sword")
      #                 return notify_fail("你使用的武器不对，难以施展" ZHAI "。\n");
      # 
      #         if (target->is_busy())
      #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
      # 
      #         if ((level = me->query_skill("miaojia-jian", 1)) < 100)
      #                 return notify_fail("你苗家剑法不够娴熟，难以施展" ZHAI "。\n");
      # 
      #         if ((int)me->query_skill("force") < 120)
      #                 return notify_fail("你的内功火候不够，难以施展" ZHAI "。\n");
      # 
      #         if ((int)me->query("max_neili") < 800)
      #                 return notify_fail("你的内力修为不够，难以施展" ZHAI "。\n");
      # 
      #         if ((int)me->query("neili") < 100)
      #                 return notify_fail("你现在真气不够，难以施展" ZHAI "。\n");
      # 
      #         if (me->query_skill_mapped("sword") != "miaojia-jian")
      #                 return notify_fail("你没有激发苗家剑法，难以施展" ZHAI "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #     msg = HIW "$N" HIW "一声清哮，剑势舒张，吞吐不定，瞬间向$n" HIW "连刺"
      #               "数剑，企图扰乱$n" HIW "的攻势。\n" NOR;
      # 
      #         me->add("neili", -30);
      #         if (random(level) > (int)target->query_skill("parry", 1) / 2)
      #         {
      #         msg += HIR "结果$p" HIR "只见$P" HIR "剑招精妙，全然"
      #                        "辨不清招中虚实，攻势登时一紧！\n" NOR;
      #                 target->start_busy(level / 18 + 2);
      #     } else
      #         {
      #         msg += CYN "可是$p" CYN "看破了$P" CYN "剑势的来路，"
      #                        "径自出招，丝毫不为所动。\n" NOR;
      #         me->start_busy(2);
      #     }
      #     message_combatd(msg, me, target);
      # 
      #     return 1;
      # }
end
