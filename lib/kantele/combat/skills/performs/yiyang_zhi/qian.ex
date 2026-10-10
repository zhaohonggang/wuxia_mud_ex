defmodule Kantele.Combat.Skills.Performs.YiyangZhi.Qian do
  @moduledoc """
  perform「一指乾坤」（source yiyang-zhi/qian.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "finger"}, {"dp", "parry"}], "level_gates": [{"force", "220"}, {"jingluo-xue", "160"}, {"yiyang-zhi", "160"}], "map_gates": [{"finger", "yiyang-zhi"}], "prepared_gates": [{"finger", "yiyang-zhi"}], "resource_gates": [{"max_neili", "2400"}, {"neili", "500"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你一阳指诀不够娴熟，难以施展", "你对经络学了解不够，难以施展", "你没有激发一阳指诀，难以施展", "你没有准备一阳指诀，难以施展", "你的内功火候不够，难以施展", "你的内力修为不足，难以施展", "你现在的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("finger") + me->query_skill("force")", "dp_formula": "target->query_skill("parry") + target->query_skill("force")"}, "color_codes": ["CYN", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["= CYN "可是$n" CYN "看破了$N" CYN "的招"
      #                          "数，连消带打挡开了这一指。\n" NOR"], "success": ["HIY "$N" HIY "陡然使出「" HIR "一指乾坤" HIY "」绝技，单指劲"
      #                 "点$n" HIY "檀中要穴，招式变化精奇之极！\n" NOR", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 75,
      #                                              HIR "$n" HIR "只觉胸口一麻，已被$N" HIR
      #                                              "一指点中，顿时气血上涌，喷出数口鲜血"
      #                                              "。\n" NOR)"]}, "damage_formula": %{"formula": "ap / 2 + random(ap / 3)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-150"}, {"neili", "-200"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-150"}, {"neili", "-200"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(4);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
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
      # #define QIAN "「" HIR "一指乾坤" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         string msg;
      #         int ap, dp;
      #         int damage;
      # 
      #         if (userp(me) && ! me->query("can_perform/yiyang-zhi/qian"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(QIAN "只能对战斗中的对手使用。\n");
      #  
      #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
      #                 return notify_fail(QIAN "只能空手施展。\n");
      # 
      #         if ((int)me->query_skill("yiyang-zhi", 1) < 160)
      #                 return notify_fail("你一阳指诀不够娴熟，难以施展" QIAN "。\n");
      # 
      #         if ((int)me->query_skill("jingluo-xue", 1) < 160)
      #                 return notify_fail("你对经络学了解不够，难以施展" QIAN "。\n");
      # 
      #         if (me->query_skill_mapped("finger") != "yiyang-zhi")
      #                 return notify_fail("你没有激发一阳指诀，难以施展" QIAN "。\n");
      # 
      #         if (me->query_skill_prepared("finger") != "yiyang-zhi")
      #                 return notify_fail("你没有准备一阳指诀，难以施展" QIAN "。\n");
      # 
      #         if ((int)me->query_skill("force") < 220)
      #                 return notify_fail("你的内功火候不够，难以施展" QIAN "。\n");
      # 
      #         if (me->query("max_neili") < 2400)
      #                 return notify_fail("你的内力修为不足，难以施展" QIAN "。\n");
      # 
      #         if ((int)me->query("neili") < 500)
      #                 return notify_fail("你现在的真气不够，难以施展" QIAN "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIY "$N" HIY "陡然使出「" HIR "一指乾坤" HIY "」绝技，单指劲"
      #               "点$n" HIY "檀中要穴，招式变化精奇之极！\n" NOR;
      # 
      #         ap = me->query_skill("finger") + me->query_skill("force");
      #         dp = target->query_skill("parry") + target->query_skill("force");
      # 
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 //damage = ap / 2 + random(ap / 3);
      #                 damage = ap / 2 + random(ap / 2);
      #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 75,
      #                                            HIR "$n" HIR "只觉胸口一麻，已被$N" HIR
      #                                            "一指点中，顿时气血上涌，喷出数口鲜血"
      #                                            "。\n" NOR);
      #                 me->add("neili", -200);
      #                 me->start_busy(2);
      #         } else
      #         {
      #                 msg += CYN "可是$n" CYN "看破了$N" CYN "的招"
      #                        "数，连消带打挡开了这一指。\n" NOR;
      #                 me->start_busy(4);
      #                 me->add("neili", -150);
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
end
