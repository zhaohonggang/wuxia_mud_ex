defmodule Kantele.Combat.Skills.Performs.SanyinShou.Sun do
  @moduledoc """
  perform「损筋诀」（source sanyin-shou/sun.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "hand"}, {"dp", "parry"}, {"skill", "sanyin-shou"}], "level_gates": [], "map_gates": [{"hand", "sanyin-shou"}], "prepared_gates": [{"hand", "sanyin-shou"}], "resource_gates": [{"max_neili", "1600"}, {"neili", "200"}], "var_gates": [{"skill", "140"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的三阴手等级不够，难以施展", "你的内力修为不足，难以施展", "你的内力不够，难以施展", "你没有激发三阴手，难以施展", "你现在没有准备使用三阴手，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("hand")", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["CYN", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["= CYN "$n" CYN "见状大吃一惊，急忙向后猛退数步，"
      #                          "终于避开了$N" CYN "这一击。\n" NOR"], "success": ["HIR "$N" HIR "悄然游走至$n" HIR "跟前，陡然使出"
      #                 "三阴手绝技「损筋诀」，单掌轻轻拂过$n" HIR "太阳"
      #                 "穴，不着半点力道。\n" NOR", "= COMBAT_D->do_damage(me, target, REMOTE_ATTACK,
      #                          damage, 0, HIR "$n" HIR "稍不留神，已被$N" HIR
      #                          "单掌拂中，只觉眼前一黑，几欲晕倒。\n" NOR)"]}, "damage_formula": %{"formula": "skill / 2 + random(skill / 2)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "receive_damage_calls": [%{"formula": "damage", "kind": "damage", "part": "jing", "source": None}, %{"formula": "damage", "kind": "wound", "part": "jing", "source": None}], "resource_adds": [{"neili", "-100"}, {"neili", "-200"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-200"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "target->start_busy(1);", "me->start_busy(4);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - target->start_busy(1);
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
      # #define SUN "「" HIR "损筋诀" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me)
      # {
      #         string msg;
      #         object target;
      #         int skill, ap, dp, damage;
      # 
      #         if (! target)
      #         {
      #                 me->clean_up_enemy();
      #                 target = me->select_opponent();
      #         }
      # 
      #         if (userp(me) && ! me->query("can_perform/sanyin-shou/sun"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         skill = me->query_skill("sanyin-shou", 1);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(SUN "只能对战斗中的对手使用。\n");
      # 
      #         if (skill < 140)
      #                 return notify_fail("你的三阴手等级不够，难以施展" SUN "。\n");
      # 
      #         if (me->query("max_neili") < 1600 )
      #                 return notify_fail("你的内力修为不足，难以施展" SUN "。\n");
      # 
      #         if (me->query("neili") < 200 )
      #                 return notify_fail("你的内力不够，难以施展" SUN "。\n");
      # 
      #         if (me->query_skill_mapped("hand") != "sanyin-shou")
      #                 return notify_fail("你没有激发三阴手，难以施展" SUN "。\n");
      # 
      #         if (me->query_skill_prepared("hand") != "sanyin-shou")
      #                 return notify_fail("你现在没有准备使用三阴手，难以施展" SUN "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIR "$N" HIR "悄然游走至$n" HIR "跟前，陡然使出"
      #               "三阴手绝技「损筋诀」，单掌轻轻拂过$n" HIR "太阳"
      #               "穴，不着半点力道。\n" NOR;
      # 
      #         damage = skill / 2 + random(skill / 2);
      # 
      #         ap = me->query_skill("hand");
      #         dp = target->query_skill("parry");
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 me->add("neili", -200);
      #                 me->start_busy(2);
      #                 target->receive_damage("jing", damage);
      #                 target->receive_wound("jing", damage);
      #                 target->start_busy(1);
      #                 msg += COMBAT_D->do_damage(me, target, REMOTE_ATTACK,
      #                        damage, 0, HIR "$n" HIR "稍不留神，已被$N" HIR
      #                        "单掌拂中，只觉眼前一黑，几欲晕倒。\n" NOR);
      #         }
      #         else
      #         {
      #                 me->add("neili", -100);
      #                 msg += CYN "$n" CYN "见状大吃一惊，急忙向后猛退数步，"
      #                        "终于避开了$N" CYN "这一击。\n" NOR;
      #                 me->start_busy(4);
      #         }
      #         message_combatd(msg, me, target);
      #         return 1;
      # }
end
