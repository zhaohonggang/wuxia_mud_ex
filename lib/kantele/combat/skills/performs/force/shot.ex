defmodule Kantele.Combat.Skills.Performs.Force.Shot do
  @moduledoc """
  exert「shot」（source force/shot.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "force"}, {"dp", "dodge"}, {"skill", "force"}], "level_gates": [{"poison", "100"}, {"throwing", "100"}], "map_gates": [{"force", "hamagong"}, {"force", "huagong-dafa"}, {"force", "huaxue-shengong"}, {"force", "shennong-xinjing"}, {"force", "xiuluo-yinshagong"}], "prepared_gates": [], "resource_gates": [{"neili", "300"}], "var_gates": [{"skill", "150"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所学的内功中没有这种功能。\n", "你的内功修为不够。\n", "你的基本毒技火候不够。\n", "你的基本暗器火候不够。\n", "在这里不能攻击他人。\n", "在这里不能攻击他人。\n", "你的真气不够。\n", "你得先准备(hand)好毒药再说。\n", "你手中所拿的", "将", "你想攻击谁？\n", "这个人正被官府保护着，还是别去招惹。\n", "比武的时候最好是正大光明的较量。\n", "对方都已经这样了，用不着这么费力吧？\n"], "amount_calls": [{"query_amount", ""}], "amount_gates": ["1"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("force") +
      #                        me->query_skill("poison") +
      #                        me->query_skill("throwing")", "dp_formula": "target->query_skill("dodge") +
      #                        target->query_skill("parry") +
      #                        target->query_skill("martial-cognize",1)"}, "color_codes": ["CYN", "HIG", "HIM", "NOR", "WHT"], "combat_messages": %{"fail": [], "other": ["HIM "$N" HIM "一声冷笑，默运" + to_chinese(f) +
      #                 HIM "内劲，手指粘住" + du->name() +
      #                 HIM "对准$n" HIM "「嗖」的弹射了出去。\n" NOR", "= WHT "然而$n" WHT "全然不放在心上，轻轻一抖，已将$N"
      #                          WHT "射来的毒素尽数震落。\n" NOR", "= HIG "$n" HIG "急忙飞身躲避，可已然不及，霎时"
      #                                  "绿光闪过，$p" HIG "顿感一阵麻痹。\n" NOR", "= CYN "可是$n" CYN "见势不妙，急忙腾挪身形，终"
      #                                  "于避开了$N" CYN "的弹毒攻击。\n" NOR"], "success": []}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": false, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(1 + random(3));", "if (! target->is_busy())", "target->start_busy(2);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1 + random(3));
      #   - if (! target->is_busy())
      #   - target->start_busy(2);
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
      # int exert(object me, object target)
      # {
      #         object du;
      #         int an, dn, ap, dp;
      #         int f, skill;
      #         string msg;
      # 
      #         f = me->query_skill_mapped("force");
      #         skill = me->query_skill("force");
      # 
      #         if (me->query_skill_mapped("force") != "xiuluo-yinshagong"
      #            && me->query_skill_mapped("force") != "huagong-dafa"
      #            && me->query_skill_mapped("force") != "hamagong"
      #            && me->query_skill_mapped("force") != "shennong-xinjing"
      #            && me->query_skill_mapped("force") != "huaxue-shengong")
      #                 return notify_fail("你所学的内功中没有这种功能。\n");
      # 
      #         if (skill < 150)
      #                 return notify_fail("你的内功修为不够。\n");
      # 
      #         if ((int)me->query_skill("poison", 1) < 100)
      #                 return notify_fail("你的基本毒技火候不够。\n");
      # 
      #         if ((int)me->query_skill("throwing", 1) < 100)
      #                 return notify_fail("你的基本暗器火候不够。\n");
      # 
      #         if (environment(me)->query("no_fight"))
      #                 return notify_fail("在这里不能攻击他人。\n");
      # 
      #         // 执行天书任务的特殊房间防止弹毒中断剧情。
      #         if (environment(me)->query("skybook"))
      #                 return notify_fail("在这里不能攻击他人。\n");
      # 
      #         if ((int)me->query("neili") < 300)
      #                 return notify_fail("你的真气不够。\n");
      # 
      #         if (! objectp(du = me->query_temp("handing")))
      #                 return notify_fail("你得先准备(hand)好毒药再说。\n");
      # 
      #         if (! mapp(du->query("poison")))
      #                 return notify_fail("你手中所拿的" + du->name() + NOR
      #                                    "不是毒药，无法弹射。\n");
      # 
      #         if (du->query("no_shot"))
      #                 return notify_fail("将" + du->name() + NOR "弹射出去"
      #                                    "？似乎不太好吧。\n");
      # 
      #         if (! target || me == target
      #            || ! target->is_character()
      #            || target->query("not_living"))
      #                 return notify_fail("你想攻击谁？\n");
      # 
      #         if (target->query_condition("die_guard"))
      #                 return notify_fail("这个人正被官府保护着，还是别去招惹。\n");
      # 
      #         if (target->query_competitor())
      #                 return notify_fail("比武的时候最好是正大光明的较量。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIM "$N" HIM "一声冷笑，默运" + to_chinese(f) +
      #               HIM "内劲，手指粘住" + du->name() +
      #               HIM "对准$n" HIM "「嗖」的弹射了出去。\n" NOR;
      # 
      #         me->start_busy(1 + random(3));
      #         me->add("neili", -100);
      # 
      #         an = me->query("max_neili") + me->query("neili") / 2;
      #         dn = target->query("max_neili") + target->query("neili") / 2;
      # 
      #         if (an / 2 + random(an) < dn * 2 / 3)
      #         {
      #                 msg += WHT "然而$n" WHT "全然不放在心上，轻轻一抖，已将$N"
      #                        WHT "射来的毒素尽数震落。\n" NOR;
      #         } else
      #         {
      #                 ap = me->query_skill("force") +
      #                      me->query_skill("poison") +
      #                      me->query_skill("throwing");
      # 
      #                 dp = target->query_skill("dodge") +
      #                      target->query_skill("parry") +
      #                      target->query_skill("martial-cognize",1);
      # 
      #                 if (ap / 2 + random(ap) > dp)
      #                 {
      #                         msg += HIG "$n" HIG "急忙飞身躲避，可已然不及，霎时"
      #                                "绿光闪过，$p" HIG "顿感一阵麻痹。\n" NOR;
      #                         target->affect_by(du->query("poison_type"),
      #                                           du->query("poison"));
      # 
      #                         if (! target->is_busy())
      #                                 target->start_busy(2);
      #                 } else
      #                 {
      #                         msg += CYN "可是$n" CYN "见势不妙，急忙腾挪身形，终"
      #                                "于避开了$N" CYN "的弹毒攻击。\n" NOR;
      #                 }
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         if (du->query_amount())
      #         {
      #                 du->add_amount(-1);
      # 
      #                 if (du->query_amount() < 1)
      #                         destruct(du);
      #         } else
      #                 destruct(du);
      # 
      #         me->want_kill(target);
      # 
      #         if (! target->is_killing(me))
      #                 target->kill_ob(me);
      # 
      #         return 1;
      # }
end
