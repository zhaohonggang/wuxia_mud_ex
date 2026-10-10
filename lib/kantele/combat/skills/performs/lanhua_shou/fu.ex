defmodule Kantele.Combat.Skills.Performs.LanhuaShou.Fu do
  @moduledoc """
  perform「兰花拂穴」（source lanhua-shou/fu.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "hand"}, {"dp", "parry"}], "level_gates": [{"jingluo-xue", "120"}, {"lanhua-shou", "120"}], "map_gates": [{"hand", "lanhua-shou"}], "prepared_gates": [{"hand", "lanhua-shou"}], "resource_gates": [{"neili", "100"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你兰花拂穴手不够娴熟，难以施展", "你对经络学的了解不够，难以施展", "你没有激发兰花拂穴手，难以施展", "你没有准备兰花拂穴手，难以施展", "你现在真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("hand")", "dp_formula": "target->query_skill("parry") / 2"}, "color_codes": ["CYN", "HIC", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["HIC "$N" HIC "反手轻轻伸出三指，婉转如一朵盛开的兰花，轻点$n"
      #                 HIC "胁下要穴。\n"", "= CYN "可是$p" CYN "看破了$P" CYN
      #                  "的企图，轻轻一跃，跳了开去。\n" NOR"], "success": ["=  HIR "$p" HIR "只觉胁下一麻，已被$P"
      #                           HIR "点个正着，顿时全身酸软，呆立当场。\n" NOR"]}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (target->is_busy())", "target->start_busy(ap / 30 + 2);", "me->start_busy(1);", "me->start_busy(2);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (target->is_busy())
      #   - target->start_busy(ap / 30 + 2);
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
      # #define FU "「" HIC "兰花拂穴" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #     string msg;
      #         int ap, dp;
      # 
      #         if (userp(me) && ! me->query("can_perform/lanhua-shou/fu"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(FU "只能对战斗中的对手使用。\n");
      # 
      #         if (objectp(me->query_temp("weapon")))
      #                 return notify_fail(FU "只能空手施展。\n");
      # 
      #         if (target->is_busy())
      #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
      # 
      #         if ((int)me->query_skill("lanhua-shou", 1) < 120)
      #                 return notify_fail("你兰花拂穴手不够娴熟，难以施展" FU "。\n");
      # 
      #         if ((int)me->query_skill("jingluo-xue", 1) < 120)
      #                 return notify_fail("你对经络学的了解不够，难以施展" FU "。\n");
      # 
      #         if (me->query_skill_mapped("hand") != "lanhua-shou")
      #                 return notify_fail("你没有激发兰花拂穴手，难以施展" FU "。\n");
      # 
      #         if (me->query_skill_prepared("hand") != "lanhua-shou")
      #                 return notify_fail("你没有准备兰花拂穴手，难以施展" FU "。\n");
      # 
      #         if ((int)me->query("neili") < 100)
      #                 return notify_fail("你现在真气不足，难以施展" FU "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #     msg = HIC "$N" HIC "反手轻轻伸出三指，婉转如一朵盛开的兰花，轻点$n"
      #               HIC "胁下要穴。\n";
      # 
      #         ap = me->query_skill("hand");
      #         dp = target->query_skill("parry") / 2;
      #     if (ap / 2 + random(ap) > dp)
      #     {
      #         msg +=  HIR "$p" HIR "只觉胁下一麻，已被$P"
      #                         HIR "点个正着，顿时全身酸软，呆立当场。\n" NOR;
      #         target->start_busy(ap / 30 + 2);
      #         me->add("neili", -100);
      #                 me->start_busy(1);
      #     } else
      #     {
      #         msg += CYN "可是$p" CYN "看破了$P" CYN
      #                "的企图，轻轻一跃，跳了开去。\n" NOR;
      #         me->start_busy(2);
      #     }
      #     message_combatd(msg, me, target);
      # 
      #     return 1;
      # }
end
