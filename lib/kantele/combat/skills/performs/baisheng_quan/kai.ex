defmodule Kantele.Combat.Skills.Performs.BaishengQuan.Kai do
  @moduledoc """
  perform「混沌初开」（source baisheng-quan/kai.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"damage", "cuff"}], "level_gates": [{"baisheng-quan", "100"}, {"force", "140"}], "map_gates": [{"cuff", "baisheng-quan"}], "prepared_gates": [{"cuff", "baisheng-quan"}], "resource_gates": [{"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "只有空手才能施展", "你的百胜神拳不够娴熟，难以施展", "你的内功修为不够，难以施展", "你没有激发百胜神拳，难以施展", "你没有准备百胜神拳，难以施展", "你现在的真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["CYN", "HIR", "NOR", "WHT"], "combat_messages": %{"fail": [], "other": ["= CYN "可是$p" CYN "识破了$P"
      #                          CYN "这一招，斜斜一跃避开。\n" NOR"], "success": ["WHT "$N" WHT "身子蓦的横移，两臂向后反钩，呼的一声朝$n"
      #                 WHT "攻去，正是「" NOR + HIR "混沌初开" NOR + WHT "」绝"
      #                 "技。\n" NOR", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 50,
      #                                              HIR "结果$n" HIR "闪避不及，$N" HIR "双"
      #                                              "拳正中$p" HIR "头部两侧，顿时口喷鲜血"
      #                                              "，几欲昏厥。\n" NOR)"]}, "damage_formula": %{"formula": "me->query_skill("cuff")"}, "resource_adds": [{"neili", "-100"}, {"neili", "-60"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-60"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
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
      # #define KAI "「" WHT "混沌初开" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         object weapon;
      #         int damage;
      #         string msg;
      # 
      #         if (userp(me) && ! me->query("can_perform/baisheng-quan/kai"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(KAI "只能对战斗中的对手使用。\n");
      # 
      #         if (objectp(weapon = me->query_temp("weapon")))
      #                 return notify_fail("只有空手才能施展" KAI "。\n");
      # 
      #         if ((int)me->query_skill("baisheng-quan", 1) < 100)
      #                 return notify_fail("你的百胜神拳不够娴熟，难以施展" KAI "。\n");
      # 
      #         if ((int)me->query_skill("force") < 140)
      #                 return notify_fail("你的内功修为不够，难以施展" KAI "。\n");
      # 
      #         if (me->query_skill_mapped("cuff") != "baisheng-quan") 
      #                 return notify_fail("你没有激发百胜神拳，难以施展" KAI "。\n");
      # 
      #         if (me->query_skill_prepared("cuff") != "baisheng-quan")
      #                 return notify_fail("你没有准备百胜神拳，难以施展" KAI "。\n");
      # 
      #         if ((int)me->query("neili") < 200)
      #                 return notify_fail("你现在的真气不足，难以施展" KAI "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = WHT "$N" WHT "身子蓦的横移，两臂向后反钩，呼的一声朝$n"
      #               WHT "攻去，正是「" NOR + HIR "混沌初开" NOR + WHT "」绝"
      #               "技。\n" NOR;
      # 
      #         if (random(me->query_skill("cuff")) > target->query_skill("dodge") / 2)
      #         {
      #                 me->start_busy(2);
      #                 damage = me->query_skill("cuff");
      #                 damage = damage / 2 + random(damage * 2 / 3);
      #                 me->add("neili", -100);
      #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 50,
      #                                            HIR "结果$n" HIR "闪避不及，$N" HIR "双"
      #                                            "拳正中$p" HIR "头部两侧，顿时口喷鲜血"
      #                                            "，几欲昏厥。\n" NOR);
      #         } else
      #         {
      #                 me->start_busy(3);
      #                 me->add("neili", -60);
      #                 msg += CYN "可是$p" CYN "识破了$P"
      #                        CYN "这一招，斜斜一跃避开。\n" NOR;
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
end
