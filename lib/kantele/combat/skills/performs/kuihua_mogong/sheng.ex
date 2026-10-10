defmodule Kantele.Combat.Skills.Performs.KuihuaMogong.Sheng do
  @moduledoc """
  perform「无声无息」（source kuihua-mogong/sheng.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "kuihua-mogong"}, {"dp", "dodge"}], "level_gates": [{"kuihua-mogong", "200"}], "map_gates": [{"dodge", "kuihua-mogong"}], "prepared_gates": [], "resource_gates": [{"max_neili", "3000"}, {"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的葵花魔功不够深厚，不会使用", "你的内力修为不足，难以施展", "你的真气不够，无法施展", "你还没有激发葵花魔功为轻功，无法施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("kuihua-mogong", 1) * 3 / 2 +
      #                me->query_skill("martial-cognize", 1)", "dp_formula": "target->query_skill("dodge") +
      #                target->query_skill("martial-cognize", 1)"}, "color_codes": ["CYN", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["= CYN "可是$p" CYN "看破了$P" CYN "的身法，并没"
      #                          "有受到任何影响。\n" NOR"], "success": ["HIR "$N" HIR "身子忽进忽退，身形诡秘异常，在$n"
      #                 HIR "身边飘忽不定。\n" NOR", "= HIR "结果$p" HIR "只能紧守门户，不敢妄自出击！\n" NOR"]}, "hit_formula": %{"left_side": "ap * 3 / 5 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-120"}, {"neili", "-80"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-120"}, {"neili", "-80"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (target->is_busy())", "target->start_busy(ap / 30 + 2);", "me->start_busy(1);", "me->start_busy(1 + random(2));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (target->is_busy())
      #   - target->start_busy(ap / 30 + 2);
      #   - me->start_busy(1);
      #   - me->start_busy(1 + random(2));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // sheng.c 无声无息
      # 
      # #include <ansi.h>
      # 
      # inherit F_SSERVER;
      # 
      # #define XI "「" HIW "无声无息" NOR "」"
      # 
      # int perform(object me, object target)
      # {
      #     string msg;
      #         int ap, dp;
      # 
      #         if (userp(me) && ! me->query("can_perform/kuihua-mogong/sheng"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #     if (! target) target = offensive_target(me);
      # 
      #     if (! target || ! me->is_fighting(target))
      #         return notify_fail(XI "只能对战斗中的对手使用。\n");
      # 
      #     if (target->is_busy())
      #         return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧！\n");
      # 
      #     if ((int)me->query_skill("kuihua-mogong", 1) < 200)
      #         return notify_fail("你的葵花魔功不够深厚，不会使用" XI "。\n");
      # 
      #         if ((int)me->query("max_neili") < 3000)
      #                 return notify_fail("你的内力修为不足，难以施展" XI "。\n");
      # 
      #     if (me->query("neili") < 200)
      #         return notify_fail("你的真气不够，无法施展" XI "！\n");
      # 
      #         if (me->query_skill_mapped("dodge") != "kuihua-mogong")
      #                 return notify_fail("你还没有激发葵花魔功为轻功，无法施展" XI "。\n");
      # 
      #        if (! living(target))
      #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #     msg = HIR "$N" HIR "身子忽进忽退，身形诡秘异常，在$n"
      #               HIR "身边飘忽不定。\n" NOR;
      # 
      #         ap = me->query_skill("kuihua-mogong", 1) * 3 / 2 +
      #              me->query_skill("martial-cognize", 1);
      #         dp = target->query_skill("dodge") +
      #              target->query_skill("martial-cognize", 1);
      # 
      #     if (ap * 3 / 5 + random(ap) > dp)
      #         {
      #         msg += HIR "结果$p" HIR "只能紧守门户，不敢妄自出击！\n" NOR;
      #         target->start_busy(ap / 30 + 2);
      #                 me->add("neili", -120);
      #                 me->start_busy(1);
      #     } else
      #         {
      #         msg += CYN "可是$p" CYN "看破了$P" CYN "的身法，并没"
      #                        "有受到任何影响。\n" NOR;
      #         me->start_busy(1 + random(2));
      #                 me->add("neili", -80);
      #     }
      #     message_combatd(msg, me, target);
      # 
      #     return 1;
      # }
end
