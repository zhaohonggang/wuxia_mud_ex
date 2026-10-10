defmodule Kantele.Combat.Skills.Performs.JiuyinShengong.Shou do
  @moduledoc """
  perform「九阴神手」（source jiuyin-shengong/shou.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "jiuyin-shengong"}, {"ap1", "jiuyin-shengong"}, {"dp1", "parry"}], "level_gates": [{"jiuyin-shengong", "260"}], "map_gates": [], "prepared_gates": [{"hand", "jiuyin-shengong"}, {"unarmed", "jiuyin-shengong"}], "resource_gates": [{"neili", "300"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "此招只能空手施展！\n", "你的九阴神功还不够娴熟，不能使用", "你的真气不够！\n", "你没有准备使用九阴神功，无法施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("jiuyin-shengong")", "dp_formula": "target->query("combat_exp") / 10000"}, "color_codes": ["HIC", "HIG", "HIM", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "$N" HIY "“哈”的一声吐出了一口气，手势奇特，软绵绵的奔向$n" HIY "的要穴！\n"", "= HIC "$n" HIC "知道来招不善，小心应对，没出一点差错。\n" NOR", "= HIM "$n" HIM "大吃一惊，连忙胡乱抵挡，居"
      #                      "然没有一点伤害，侥幸得脱！\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 90,
      #                                          HIR "$n" HIR "只觉此招，阴柔无比，诡异莫测，"
      #                                              "心中一惊，却猛然间觉得一股阴风透骨而过。\n" NOR)", "= HIR "这一招完全超出了$n" HIR "的想象，被$N" HIR "结结实实的打中了檀中大穴，浑身真气登时涣散！\n" NOR"]}, "damage_formula": %{"formula": "ap1 + random(ap1)"}, "exp_compare": [{"ap", "dp"}], "resource_adds": [{"neili", "-140"}, {"neili", "-200"}, {"neili", "-60"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-140"}, {"neili", "-200"}, {"neili", "-60"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(1 + random(3));", "target->start_busy(1 + random(2));"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1 + random(3));
      #   - target->start_busy(1 + random(2));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // shou.c 九阴神手
      # 
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # inherit F_SSERVER;
      # 
      # #define SHOU "「" HIG "九阴神手" NOR "」"
      # 
      # int perform(object me, object target)
      # {
      #     string msg;
      #     int ap, dp, ap1, dp1, damage;
      # 
      #     if (userp(me) && !me->query("can_perform/jiuyin-shengong/shou"))
      #         return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #     if (!target)
      #         target = offensive_target(me);
      # 
      #     if (!target || !me->is_fighting(target))
      #         return notify_fail(SHOU "只能在战斗中对对手使用。\n");
      # 
      #     if (me->query_temp("weapon"))
      #         return notify_fail("此招只能空手施展！\n");
      # 
      #     if (me->query_skill("jiuyin-shengong", 1) < 260)
      #         return notify_fail("你的九阴神功还不够娴熟，不能使用" SHOU "！\n");
      # 
      #     if (me->query("neili") < 300)
      #         return notify_fail("你的真气不够！\n");
      # 
      #     if (me->query_skill_prepared("hand") != "jiuyin-shengong" && me->query_skill_prepared("unarmed") != "jiuyin-shengong")
      #         return notify_fail("你没有准备使用九阴神功，无法施展" SHOU "。\n");
      # 
      #     if (!living(target))
      #         return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #     msg = HIY "$N" HIY "“哈”的一声吐出了一口气，手势奇特，软绵绵的奔向$n" HIY "的要穴！\n";
      # 
      #     ap = me->query_skill("jiuyin-shengong");
      #     dp = target->query("combat_exp") / 10000;
      #     me->add("neili", -60);
      #     me->start_busy(1 + random(3));
      # 
      #     me->want_kill(target);
      # 
      #     if (dp >= 100) // 此招对百万经验以上的人无效
      #     {              // 但是仍然受到伤害
      # 
      #         ap1 = me->query_skill("jiuyin-shengong", 1) + me->query_skill("force", 1);
      #         dp1 = target->query_skill("parry", 1) + target->query_skill("dodge", 1);
      #         //damage = ap1 + random(ap1);
      #         damage = ap1 * 2 + random(ap1);
      #         if (ap1 / 2 + random(ap1) > dp1)
      #         {
      #             msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 90,
      #                                        HIR "$n" HIR "只觉此招，阴柔无比，诡异莫测，"
      #                                            "心中一惊，却猛然间觉得一股阴风透骨而过。\n" NOR);
      #             me->add("neili", -140);
      #         }
      # 
      #         else
      #             msg += HIC "$n" HIC "知道来招不善，小心应对，没出一点差错。\n" NOR;
      #         message_combatd(msg, me, target);
      #         target->start_busy(1 + random(2));
      #         return 1;
      #     }
      #     else if (random(ap) > dp)
      #     {
      #         msg += HIR "这一招完全超出了$n" HIR "的想象，被$N" HIR "结结实实的打中了檀中大穴，浑身真气登时涣散！\n" NOR;
      #         message_combatd(msg, me, target);
      #         me->add("neili", -200);
      #         target->die(me);
      #         return 1;
      #     }
      #     else
      #     {
      #         msg += HIM "$n" HIM "大吃一惊，连忙胡乱抵挡，居"
      #                    "然没有一点伤害，侥幸得脱！\n" NOR;
      #     }
      # 
      #     message_combatd(msg, me, target);
      # 
      #     return 1;
      # }
end
