defmodule Kantele.Combat.Skills.Performs.TianluoDiwang.Wang do
  @moduledoc """
  perform「天罗地网」（source tianluo-diwang/wang.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"level", "tianluo-diwang"}], "level_gates": [{"dodge", "40"}, {"tianluo-diwang", "60"}], "map_gates": [], "prepared_gates": [{"strike", "tianluo-diwang"}], "resource_gates": [{"neili", "70"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你必须空手才能施展", "你的天罗地网掌还不够娴熟，无法施展", "你的轻功修为不够，无法施展", "你没有准备天罗地网掌，难以施展", "你现在真气不够，无法使用", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["CYN", "HIG", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIG "\n$N" HIG "双掌齐出，幻化出无数掌影，将$n" HIG "团团笼罩。" NOR", "CYN "可是$p" CYN "身形一闪，跃出$P" CYN "的掌力"
      #                         "所及的范围。\n" NOR"], "success": ["HIR "结果$p" HIR "被$P" HIR "压制的难以反击，"
      #                         "只能竭力抵挡！\n" NOR"]}, "resource_adds": [{"neili", "-60"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-60"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (target->is_busy())", "target->start_busy(level / 16 + 2);", "me->start_busy(2 + random(2));", "me->start_busy(1);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (target->is_busy())
      #   - target->start_busy(level / 16 + 2);
      #   - me->start_busy(2 + random(2));
      #   - me->start_busy(1);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # 
      # #define WANG "「" HIW "天罗地网" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      # //    object weapon;
      #     int level;
      #     string msg;
      # 
      #     if (! target) target = offensive_target(me);
      # 
      #         if (userp(me) && ! me->query("can_perform/tianluo-diwang/wang"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #     if (! target || ! me->is_fighting(target))
      #         return notify_fail(WANG "只能对战斗中的对手使用。\n");
      # 
      #     if (me->query_temp("weapon"))
      #         return notify_fail("你必须空手才能施展" WANG "。\n");
      # 
      #     if (target->is_busy())
      #         return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧！\n");
      # 
      #     if ((level = me->query_skill("tianluo-diwang", 1)) < 60)
      #         return notify_fail("你的天罗地网掌还不够娴熟，无法施展" WANG "。\n");
      # 
      #     if (me->query_skill("dodge") < 40)
      #         return notify_fail("你的轻功修为不够，无法施展" WANG "。\n");
      # 
      #         if (me->query_skill_prepared("strike") != "tianluo-diwang")
      #                 return notify_fail("你没有准备天罗地网掌，难以施展" WANG "。\n");
      # 
      #         if (me->query("neili") < 70)
      #                 return notify_fail("你现在真气不够，无法使用" WANG "。\n");
      # 
      #         if (! living(target))
      #                return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #     msg = HIG "\n$N" HIG "双掌齐出，幻化出无数掌影，将$n" HIG "团团笼罩。" NOR;
      #         message_sort(msg, me, target);
      # 
      #         me->add("neili", -60);
      #         if (random(level) > (int)target->query_skill("dodge", 1) / 2)
      #         {
      #         msg = HIR "结果$p" HIR "被$P" HIR "压制的难以反击，"
      #                       "只能竭力抵挡！\n" NOR;
      # 
      #         target->start_busy(level / 16 + 2);
      #                 me->start_busy(2 + random(2));
      #     } else
      #         {
      #         msg = CYN "可是$p" CYN "身形一闪，跃出$P" CYN "的掌力"
      #                       "所及的范围。\n" NOR;
      # 
      #         me->start_busy(1);
      #     }
      #     message_vision(msg, me, target);
      # 
      #     return 1;
      # }
end
