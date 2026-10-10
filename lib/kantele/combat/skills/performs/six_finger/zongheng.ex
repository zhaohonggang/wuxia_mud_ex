defmodule Kantele.Combat.Skills.Performs.SixFinger.Zongheng do
  @moduledoc """
  perform「zongheng」（source six-finger/zongheng.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "six-finger"}, {"dp", "force"}], "level_gates": [{"six-finger", "120"}], "map_gates": [{"finger", "six-finger"}], "prepared_gates": [], "resource_gates": [{"neili", "100"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["「纵横」只能对战斗中的对手使用。\n", "你的六脉神剑火候不够，不会使用「纵横」。\n", "你的真气不够，无法施展「纵横」。\n", "你必须空手才能施展「纵横」。\n", "你没有激发六脉神剑，无法施展「纵横」。\n", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("six-finger", 1) +
      #                me->query_skill("finger", 1) / 2", "dp_formula": "target->query_skill("force")"}, "color_codes": ["CYN", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": ["= CYN "可是$p" CYN "并不慌张，运起内功将$P"
      #                          CYN "的剑气尽数化解。\n" NOR"], "other": ["HIW "只见$N" HIW "一声轻笑，十指纷弹，剑气如奔，连绵无尽的缕缕剑气豁然贯向$n" HIW "！\n" NOR"], "success": ["= HIR "结果$p" HIR "被这纵横交错的剑气逼得手忙脚乱，应接不暇！\n" NOR"]}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": [], "apply_adds": [], "busy_lines": ["if (target->is_busy())", "target->start_busy(ap / 21 + 2);", "me->start_busy(2);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (target->is_busy())
      #   - target->start_busy(ap / 21 + 2);
      #   - me->start_busy(2);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         string msg;
      #         int ap, dp;
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail("「纵横」只能对战斗中的对手使用。\n");
      # 
      #         if (target->is_busy())
      #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧！\n");
      #                 
      #         if ((int)me->query_skill("six-finger", 1) < 120)
      #                 return notify_fail("你的六脉神剑火候不够，不会使用「纵横」。\n");
      # 
      #         if (me->query("neili") < 100)
      #                 return notify_fail("你的真气不够，无法施展「纵横」。\n");
      # 
      #         if (me->query_temp("weapon"))
      #                 return notify_fail("你必须空手才能施展「纵横」。\n");
      # 
      #         if (me->query_skill_mapped("finger") != "six-finger")
      #                 return notify_fail("你没有激发六脉神剑，无法施展「纵横」。\n");
      # 
      #        if (! living(target))
      #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIW "只见$N" HIW "一声轻笑，十指纷弹，剑气如奔，连绵无尽的缕缕剑气豁然贯向$n" HIW "！\n" NOR;
      # 
      #         ap = me->query_skill("six-finger", 1) +
      #              me->query_skill("finger", 1) / 2;
      #         dp = target->query_skill("force");
      # 
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 msg += HIR "结果$p" HIR "被这纵横交错的剑气逼得手忙脚乱，应接不暇！\n" NOR;
      #                 target->start_busy(ap / 21 + 2);
      #         } else
      #         {
      #                 msg += CYN "可是$p" CYN "并不慌张，运起内功将$P"
      #                        CYN "的剑气尽数化解。\n" NOR;
      #                 me->start_busy(2);
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
end
