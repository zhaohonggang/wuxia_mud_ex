defmodule Kantele.Combat.Skills.Performs.GuzhuoZhang.Zhuo do
  @moduledoc """
  perform「大巧若拙」（source guzhuo-zhang/zhuo.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "strike"}, {"dp", "parry"}], "level_gates": [{"force", "220"}, {"guzhuo-zhang", "150"}], "map_gates": [{"strike", "guzhuo-zhang"}], "prepared_gates": [{"strike", "guzhuo-zhang"}], "resource_gates": [{"max_neili", "1800"}, {"neili", "300"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你内功修为不够，难以施展", "你内力修为不够，难以施展", "你古拙掌法火候不够，难以施展", "你没有激发古拙掌法，难以施展", "你没有准备古拙掌法，难以施展", "你现在真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("strike")", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["CYN", "HIR", "NOR", "WHT"], "combat_messages": %{"fail": [], "other": ["WHT "$N" WHT "手腕一探，平平推出一掌，顿时掌风激进，尘沙四起，直"
      #                 "刮得$n" WHT "面庞隐隐生疼。\n" NOR", "= CYN "可是$n" CYN "不慌不忙，看破了$N"
      #                          CYN "此招虚实，并没有受到半点影响。\n" NOR"], "success": ["= HIR "$n" HIR "见$N" HIR "掌风凌厉，慌"
      #                          "忙招架，顿时便失了先机。\n" NOR"]}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-150"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-150"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (target->is_busy())", "target->start_busy((int)me->query_skill("guzhuo-zhang", 1) / 22 + 2);", "me->start_busy(1);", "me->start_busy(2);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (target->is_busy())
      #   - target->start_busy((int)me->query_skill("guzhuo-zhang", 1) / 22 + 2);
      #   - me->start_busy(1);
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
      # #define ZHUO "「" WHT "大巧若拙" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         string msg;
      #         int ap, dp;
      # 
      #         if (userp(me) && ! me->query("can_perform/guzhuo-zhang/zhuo"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(ZHUO "只能对战斗中的对手使用。\n");
      # 
      #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
      #                 return notify_fail(ZHUO "只能空手使用。\n");
      # 
      #         if (target->is_busy())
      #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
      # 
      #         if ((int)me->query_skill("force") < 220)
      #                 return notify_fail("你内功修为不够，难以施展" ZHUO "。\n");
      # 
      #         if ((int)me->query("max_neili") < 1800)
      #                 return notify_fail("你内力修为不够，难以施展" ZHUO "。\n");
      # 
      #         if ((int)me->query_skill("guzhuo-zhang", 1) < 150)
      #                 return notify_fail("你古拙掌法火候不够，难以施展" ZHUO "。\n");
      # 
      #         if (me->query_skill_mapped("strike") != "guzhuo-zhang")
      #                 return notify_fail("你没有激发古拙掌法，难以施展" ZHUO "。\n");
      # 
      #         if (me->query_skill_prepared("strike") != "guzhuo-zhang")
      #                 return notify_fail("你没有准备古拙掌法，难以施展" ZHUO "。\n");
      # 
      #         if ((int)me->query("neili") < 300)
      #                 return notify_fail("你现在真气不够，难以施展" ZHUO "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = WHT "$N" WHT "手腕一探，平平推出一掌，顿时掌风激进，尘沙四起，直"
      #               "刮得$n" WHT "面庞隐隐生疼。\n" NOR;
      #         me->add("neili", -150);
      # 
      #         ap = me->query_skill("strike");
      #         dp = target->query_skill("parry");
      # 
      #         if (ap / 2 + random(ap) > dp)
      # 
      #         {
      #                 msg += HIR "$n" HIR "见$N" HIR "掌风凌厉，慌"
      #                        "忙招架，顿时便失了先机。\n" NOR;
      #                 target->start_busy((int)me->query_skill("guzhuo-zhang", 1) / 22 + 2);
      #                 me->start_busy(1);
      #         } else
      #         {
      #                 msg += CYN "可是$n" CYN "不慌不忙，看破了$N"
      #                        CYN "此招虚实，并没有受到半点影响。\n" NOR;
      #                 me->start_busy(2);
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
end
