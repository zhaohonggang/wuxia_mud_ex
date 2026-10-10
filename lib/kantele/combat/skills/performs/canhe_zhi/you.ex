defmodule Kantele.Combat.Skills.Performs.CanheZhi.You do
  @moduledoc """
  perform「幽冥剑气」（source canhe-zhi/you.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [], "level_gates": [{"canhe-zhi", "200"}], "map_gates": [{"finger", "canhe-zhi"}], "prepared_gates": [{"finger", "canhe-zhi"}], "resource_gates": [{"max_neili", "2500"}, {"neili", "500"}], "var_gates": [{"i", "6"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你必须空手才能使用", "你的参合指修为有限，难以施展", "你没有激发参合指，难以施展", "你现在没有准备使用参合指，难以施展", "你的内力修为不足，难以施展", "你的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIW", "MAG", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "只见$N" HIW "身形一展，身法陡然变得诡异无比，聚力于指悄然点"
      #                 "出，数股剑气直袭$n" HIW "要穴而去。\n" NOR"], "success": []}, "resource_adds": [{"neili", "-300"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-300"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(1 + random(5));", "if (random(2) == 1 && ! target->is_busy())", "target->start_busy(1);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1 + random(5));
      #   - if (random(2) == 1 && ! target->is_busy())
      #   - target->start_busy(1);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define YOU "「" MAG "幽冥剑气" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         // int damage;
      #         string msg;
      #         // int ap, dp;
      #         int i;
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (userp(me) && ! me->query("can_perform/canhe-zhi/you"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(YOU "只能对战斗中的对手使用。\n");
      # 
      #         if (objectp(me->query_temp("weapon")))
      #                 return notify_fail("你必须空手才能使用" YOU "。\n");
      # 
      #         if ((int)me->query_skill("canhe-zhi", 1) < 200)
      #                 return notify_fail("你的参合指修为有限，难以施展" YOU "。\n");
      # 
      #         if (me->query_skill_mapped("finger") != "canhe-zhi")
      #                 return notify_fail("你没有激发参合指，难以施展" YOU "。\n");
      # 
      #         if (me->query_skill_prepared("finger") != "canhe-zhi")
      #                 return notify_fail("你现在没有准备使用参合指，难以施展" YOU "。\n");
      # 
      #         if ((int)me->query("max_neili") < 2500)
      #                 return notify_fail("你的内力修为不足，难以施展" YOU "。\n");
      # 
      #         if ((int)me->query("neili") < 500)
      #                 return notify_fail("你的真气不够，难以施展" YOU "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIW "只见$N" HIW "身形一展，身法陡然变得诡异无比，聚力于指悄然点"
      #               "出，数股剑气直袭$n" HIW "要穴而去。\n" NOR;
      # 
      #         message_combatd(msg, me, target);
      # 
      #         me->start_busy(1 + random(5));
      #         me->add("neili", -300);
      # 
      #         for (i = 0; i < 6; i++)
      #         {
      #                 if (! me->is_fighting(target))
      #                         break;
      # 
      #                 if (random(2) == 1 && ! target->is_busy())
      #                         target->start_busy(1);
      # 
      #                 COMBAT_D->do_attack(me, target, 0, 0);
      #         }
      # 
      #         return 1;
      # }
end
