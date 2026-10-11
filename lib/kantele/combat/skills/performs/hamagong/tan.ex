defmodule Kantele.Combat.Skills.Performs.Hamagong.Tan do
  @moduledoc """
  exert「tan」（source hamagong/tan.c，由 translate_perform.py 生成，inherit F_SSERVER）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats

  @impl true
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

  # TODO(migrate) 门槛由提取器机械生成，文案/查法需按原始源码核对
  defp check_gates(character) do
    with :ok <- check_levels(character),
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "hamagong") < 100 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "poison") < 80 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 500 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 200}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}

    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-200"}], "assign_refs": [{"ap", "poison"}], "busy_lines": ["me->start_busy(2 + random(2));"], "level_gates": [{"hamagong", "100"}, {"poison", "80"}], "remote_damage": false, "resource_gates": [{"neili", "500"}]}

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
