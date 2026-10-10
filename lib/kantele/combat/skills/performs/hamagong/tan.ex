defmodule Kantele.Combat.Skills.Performs.Hamagong.Tan do
  @moduledoc """
  exert「tan」（source hamagong/tan.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "poison"}], "level_gates": [{"hamagong", "100"}, {"poison", "80"}], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "500"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["这里不能战斗，你不可以使用毒技伤人。\n", "你想攻击谁？\n", "比武的时候最好是正大光明的较量。\n", "你的基本毒技火候不够。\n", "你的内功火候不够。\n", "你现在内力不足，不能弹射毒药。\n", "你得先准备(hand)好毒药再说。\n", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("poison", 1) / 2 +
      #                        me->query_skill("force")"}, "color_codes": ["CYN", "GRN", "NOR", "WHT"], "combat_messages": %{"fail": [], "other": ["CYN "$N" CYN "运转内力，轻轻悬起一些" + du->name() +
      #                 CYN "对准$n" CYN "弹了过去。\n" NOR", "= WHT "然而$n轻轻一抖，将$N射过来的" + du->name() +
      #                          WHT "悉数震开。\n" NOR", "= WHT "$n见势不妙，急忙腾挪身形，避开了$N的攻击。\n" NOR", "= GRN "$n连忙躲闪，结果仍然觉得微微一阵酸麻。\n" NOR"], "success": []}, "resource_adds": [{"neili", "-200"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": false, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-200"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2 + random(2));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2 + random(2));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // 弹射毒药
      # 
      # #include <ansi.h>
      # 
      # inherit F_SSERVER;
      # 
      # int exert(object me, object target)
      # {
      #     object du;
      #     // int damage;
      #   int ap;
      #     string msg;
      # 
      #   if (environment(me)->query("no_fight"))
      #           return notify_fail("这里不能战斗，你不可以使用毒技伤人。\n");
      # 
      #   if (! target || me == target)
      #           return notify_fail("你想攻击谁？\n");
      # 
      #     if (target->query_competitor())
      #         return notify_fail("比武的时候最好是正大光明的较量。\n");
      # 
      #     if ((int)me->query_skill("poison", 1) < 80)
      #         return notify_fail("你的基本毒技火候不够。\n");
      # 
      #     if ((int)me->query_skill("hamagong", 1) < 100)
      #         return notify_fail("你的内功火候不够。\n");
      # 
      #     if ((int)me->query("neili") < 500)
      #         return notify_fail("你现在内力不足，不能弹射毒药。\n");
      # 
      #   if (! objectp(du = me->query_temp("handing")))
      #           return notify_fail("你得先准备(hand)好毒药再说。\n");
      # 
      #   if (! mapp(du->query("poison")))
      #           return notify_fail(du->name() + "又不是毒药，你乱弹什么？\n");
      # 
      #   if (! living(target))
      #         return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #     msg = CYN "$N" CYN "运转内力，轻轻悬起一些" + du->name() +
      #               CYN "对准$n" CYN "弹了过去。\n" NOR;
      #         me->start_busy(2 + random(2));
      #         me->add("neili", -200);
      # 
      #         if (me->query("neili") / 2 + random(me->query("neili")) <
      #             target->query("neili"))
      #         {
      #                 msg += WHT "然而$n轻轻一抖，将$N射过来的" + du->name() +
      #                        WHT "悉数震开。\n" NOR;
      #         } else
      #         {
      #                 ap = me->query_skill("poison", 1) / 2 +
      #                      me->query_skill("force");
      #                 if (ap / 2 + random(ap) < target->query_skill("dodge") * 3 / 2)
      #                 {
      #                         msg += WHT "$n见势不妙，急忙腾挪身形，避开了$N的攻击。\n" NOR;
      #                 } else
      #                 {
      #                         msg += GRN "$n连忙躲闪，结果仍然觉得微微一阵酸麻。\n" NOR;
      #                         target->affect_by(du->query("poison_type"), du->query("poison"));
      #                 }
      #         }
      # 
      #         destruct(du);
      #     message_combatd(msg, me, target);
      #         me->want_kill(target);
      #         if (! target->is_killing(me)) target->kill_ob(me);
      # 
      #     return 1;
      # }
end
