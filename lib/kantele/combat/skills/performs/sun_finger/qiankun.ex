defmodule Kantele.Combat.Skills.Performs.SunFinger.Qiankun do
  @moduledoc """
  perform「qiankun」（source sun-finger/qiankun.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "finger"}, {"dp", "parry"}], "level_gates": [{"force", "160"}, {"sun-finger", "100"}], "map_gates": [{"finger", "sun-finger"}], "prepared_gates": [], "resource_gates": [{"neili", "500"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["「一指乾坤」只能在战斗中使用。\n", "你的一阳指修为不够，目前还不能施展一指乾坤绝技！\n", "你内功火候不够，难以施展一指乾坤！\n", "你的真气不够，无法施展「一指乾坤」！\n", "你没有激发一阳指法，无法使用「一指乾坤」！\n", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("finger") + me->query_skill("force")", "dp_formula": "target->query_skill("parry") + target->query_skill("force")"}, "color_codes": ["CYN", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "$N" HIY "使出一阳指绝技「一指乾坤」，攻向$n"
      #                 HIY "的要穴，招式变化精奇之极！\n" HIY", "= CYN "可是$p" CYN "看破了$P"
      #                          CYN "急忙退闪，连消带打躲开了这一击。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 66,
      #                                              HIR "结果$p" HIR "没能避开$P"
      #                                              HIR "这一指，正被点中檀中大穴，浑身"
      #                                              "气血登时倒流，哇哇连吐几口鲜血！\n" NOR)"]}, "damage_formula": %{"formula": "ap / 3 + random(ap / 4)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-200"}, {"neili", "-50"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-200"}, {"neili", "-50"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(1);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1);
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // qiankun.c 一阳指 「一指乾坤」
      # 
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #     string msg;
      #         int ap, dp;
      #         int damage;
      # 
      #     if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail("「一指乾坤」只能在战斗中使用。\n");
      # 
      #     if ((int)me->query_skill("sun-finger", 1) < 100)
      #         return notify_fail("你的一阳指修为不够，目前还不能施展一指乾坤绝技！\n");
      # 
      #     if ((int)me->query_skill("force") < 160)
      #         return notify_fail("你内功火候不够，难以施展一指乾坤！\n");
      # 
      #     if ((int)me->query("neili") < 500)
      #         return notify_fail("你的真气不够，无法施展「一指乾坤」！\n");
      # 
      #     if (me->query_skill_mapped("finger") != "sun-finger")
      #         return notify_fail("你没有激发一阳指法，无法使用「一指乾坤」！\n");
      # 
      #        if (! living(target))
      #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #     msg = HIY "$N" HIY "使出一阳指绝技「一指乾坤」，攻向$n"
      #               HIY "的要穴，招式变化精奇之极！\n" HIY;
      # 
      #         ap = me->query_skill("finger") + me->query_skill("force");
      #         dp = target->query_skill("parry") + target->query_skill("force");
      #     if (ap / 2 + random(ap) > dp)
      #     {
      #                 damage = ap / 3 + random(ap / 4);
      #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 66,
      #                                            HIR "结果$p" HIR "没能避开$P"
      #                                            HIR "这一指，正被点中檀中大穴，浑身"
      #                                            "气血登时倒流，哇哇连吐几口鲜血！\n" NOR);
      #         me->add("neili", -200);
      #                 me->start_busy(1);
      #     } else
      #     {
      #         msg += CYN "可是$p" CYN "看破了$P"
      #                        CYN "急忙退闪，连消带打躲开了这一击。\n" NOR;
      #         me->start_busy(3);
      #                 me->add("neili", -50);
      #     }
      #     message_combatd(msg, me, target);
      # 
      #     return 1;
      # }
end
