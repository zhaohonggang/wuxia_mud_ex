defmodule Kantele.Combat.Skills.Performs.TianyuQijian.Ju do
  @moduledoc """
  perform「聚剑诀」（source tianyu-qijian/ju.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "force"}, {"damage", "sword"}, {"dp", "force"}], "level_gates": [{"force", "180"}, {"tianyu-qijian", "130"}], "map_gates": [{"sword", "tianyu-qijian"}], "prepared_gates": [], "resource_gates": [{"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你的天羽奇剑不够娴熟，难以施展", "你的内功火候不足，难以施展", "你现在的真气不足，难以施展", "你没有激发天羽奇剑，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("force")", "dp_formula": "target->query_skill("force")"}, "color_codes": ["CYN", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["= CYN "可是$p" CYN "猛地向前一跃,跳出了$P"
      #                          CYN "的攻击范围。\n"NOR"], "success": ["HIR "$N" HIR "手腕轻轻一抖，手中的" + weapon->name() +
      #             HIR "化作一道彩虹，光华眩目，笼罩了$n" HIR "。\n" NOR", "= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,
      #                                              HIR "只见$N" HIR "剑花聚为一线，穿向$n"
      #                                              HIR "，$p" HIR "只觉一股热流穿心而过，"
      #                                              "喉头一甜，鲜血狂喷而出！\n" NOR)"]}, "damage_formula": %{"formula": "(int)me->query_skill("sword")"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-160"}, {"neili", "-80"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-160"}, {"neili", "-80"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(4);"], "remote_damage": true, "set_flags": [], "temp_set": []}
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
      # #define JU "「" HIR "聚剑诀" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #     object weapon;
      #     int damage;
      #     int ap, dp;
      #     string msg;
      # 
      #         if (userp(me) && ! me->query("can_perform/tianyu-qijian/ju"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #     if (! target) target = offensive_target(me);
      # 
      #     if (! target || ! me->is_fighting(target))
      #                 return notify_fail(JU "只能对战斗中的对手使用。\n");
      # 
      #     if (! objectp(weapon = me->query_temp("weapon")) ||
      #         (string)weapon->query("skill_type") != "sword")
      #                 return notify_fail("你使用的武器不对，难以施展" JU "。\n");
      # 
      #     if ((int)me->query_skill("tianyu-qijian", 1) < 130)
      #                 return notify_fail("你的天羽奇剑不够娴熟，难以施展" JU "。\n");
      # 
      #         if ((int)me->query_skill("force") < 180)
      #                 return notify_fail("你的内功火候不足，难以施展" JU "。\n");
      # 
      #         if ((int)me->query("neili") < 200)
      #                 return notify_fail("你现在的真气不足，难以施展" JU "。\n");
      # 
      #         if (me->query_skill_mapped("sword") != "tianyu-qijian")
      #                 return notify_fail("你没有激发天羽奇剑，难以施展" JU "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #     msg = HIR "$N" HIR "手腕轻轻一抖，手中的" + weapon->name() +
      #           HIR "化作一道彩虹，光华眩目，笼罩了$n" HIR "。\n" NOR;
      # 
      #     ap = me->query_skill("force");
      #     dp = target->query_skill("force");
      #     if (ap / 2 + random(ap) > dp)
      #     {
      #         damage = (int)me->query_skill("sword");
      #         damage += random(damage);
      # 
      #         me->add("neili", -160);
      #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,
      #                                            HIR "只见$N" HIR "剑花聚为一线，穿向$n"
      #                                            HIR "，$p" HIR "只觉一股热流穿心而过，"
      #                                            "喉头一甜，鲜血狂喷而出！\n" NOR);
      #         me->start_busy(2);
      #     } else
      #     {
      #         msg += CYN "可是$p" CYN "猛地向前一跃,跳出了$P"
      #                        CYN "的攻击范围。\n"NOR;
      #         me->add("neili", -80);
      #         me->start_busy(4);
      #     }
      #     message_combatd(msg, me, target);
      # 
      #     return 1;
      # }
end
