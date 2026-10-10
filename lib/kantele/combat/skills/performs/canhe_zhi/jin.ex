defmodule Kantele.Combat.Skills.Performs.CanheZhi.Jin do
  @moduledoc """
  perform「金刚剑气」（source canhe-zhi/jin.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "canhe-zhi"}, {"dp", "buddhism"}], "level_gates": [{"canhe-zhi", "160"}], "map_gates": [], "prepared_gates": [{"finger", "canhe-zhi"}], "resource_gates": [{"max_neili", "2500"}, {"neili", "500"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你必须空手才能使用", "你的参合指修为有限，难以施展", "你现在没有准备使用参合指，难以施展", "你的内力修为不足，难以施展", "你的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("canhe-zhi", 1) + me->query_skill("force")", "dp_formula": "target->query_skill("buddhism", 1) + target->query_skill("force")"}, "callback_functions": [%{"body": "target->receive_damage("jing", damage / 6, me);
      #           target->receive_wound("jing", damage / 10, me);
      #           return  HIR "只听“噗嗤”一声，指力竟在$n" HIR
      #                   "胸前穿了一个血肉模糊的大洞，透体而入。\n" NOR;", "name": "final", "params": "object me, object target, int damage", "return_type": "string"}], "color_codes": ["CYN", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "$N" HIY "双手合十，微微一笑，颇得拈花之意。食指并中指"
      #                 "轻轻一弹，顿时一屡罡气电射而出，朝$n" HIY "袭去。\n" NOR", "= HIY "但见$n" HIY "也即脸露笑容，衣袖轻轻一拂，顺势"
      #                          "裹上，顿将$N" HIY "的指力消逝殆尽。\n" NOR", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 75,
      #                                              (: final, me, target, damage :))", "= CYN "$n" CYN "见$N" CYN "来势汹涌，不敢轻易"
      #                          "招架，急忙提气跃开。\n" NOR"], "success": []}, "damage_formula": %{"formula": "ap + random(ap / 2)"}, "do_damage_calls": [%{"attack_type": "UNARMED_ATTACK", "callback": "final", "damage_factor": 75, "damage_var": "damage"}], "hit_formula": %{"left_side": "ap * 2 / 3 + random(ap)", "operator": ">", "right_side": "dp"}, "receive_damage_calls": [%{"formula": "damage / 6", "kind": "damage", "part": "jing", "source": "me"}, %{"formula": "damage / 10", "kind": "wound", "part": "jing", "source": "me"}], "resource_adds": [{"neili", "-200"}, {"neili", "-400"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-200"}, {"neili", "-400"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(3);", "me->start_busy(4);", "me->start_busy(4);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3);
      #   - me->start_busy(4);
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
      # #define JIN "「" HIY "金刚剑气" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # string final(object me, object target, int damage);
      # 
      # int perform(object me, object target)
      # {
      #         int damage;
      #         string msg;
      #         int ap, dp;
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (userp(me) && ! me->query("can_perform/canhe-zhi/jin"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(JIN "只能对战斗中的对手使用。\n");
      # 
      #         if (objectp(me->query_temp("weapon")))
      #                 return notify_fail("你必须空手才能使用" JIN "。\n");
      # 
      #         if ((int)me->query_skill("canhe-zhi", 1) < 160)
      #                 return notify_fail("你的参合指修为有限，难以施展" JIN "。\n");
      # 
      #         if (me->query_skill_prepared("finger") != "canhe-zhi")
      #                 return notify_fail("你现在没有准备使用参合指，难以施展" JIN "。\n");
      # 
      #         if ((int)me->query("max_neili") < 2500)
      #                 return notify_fail("你的内力修为不足，难以施展" JIN "。\n");
      # 
      #         if ((int)me->query("neili") < 500)
      #                 return notify_fail("你的真气不够，难以施展" JIN "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIY "$N" HIY "双手合十，微微一笑，颇得拈花之意。食指并中指"
      #               "轻轻一弹，顿时一屡罡气电射而出，朝$n" HIY "袭去。\n" NOR;  
      # 
      #         ap = me->query_skill("canhe-zhi", 1) + me->query_skill("force");
      #         dp = target->query_skill("buddhism", 1) + target->query_skill("force");
      #         me->start_busy(3);
      # 
      #         if ((int)target->query_skill("buddhism", 1) >= 200
      #             && random(5) == 1)
      #         {
      #                 me->add("neili", -400);
      #                 me->start_busy(4);
      #                 msg += HIY "但见$n" HIY "也即脸露笑容，衣袖轻轻一拂，顺势"
      #                        "裹上，顿将$N" HIY "的指力消逝殆尽。\n" NOR;
      #         } else
      #         if (ap * 2 / 3 + random(ap) > dp)
      #         { 
      #                 damage = ap + random(ap / 2);
      #                 me->add("neili", -400);
      #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 75,
      #                                            (: final, me, target, damage :));
      #         } else
      #         {
      #                 me->add("neili", -200);
      #                 me->start_busy(4);
      #                 msg += CYN "$n" CYN "见$N" CYN "来势汹涌，不敢轻易"
      #                        "招架，急忙提气跃开。\n" NOR;
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
      # 
      # string final(object me, object target, int damage)
      # {
      #         target->receive_damage("jing", damage / 6, me);
      #         target->receive_wound("jing", damage / 10, me);
      #         return  HIR "只听“噗嗤”一声，指力竟在$n" HIR
      #                 "胸前穿了一个血肉模糊的大洞，透体而入。\n" NOR;
      # }
end
