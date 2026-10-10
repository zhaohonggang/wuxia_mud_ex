defmodule Kantele.Combat.Skills.Performs.FiveAvoid.Break do
  @moduledoc """
  perform「break」（source five-avoid/break.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"count", "five-avoid"}], "level_gates": [{"force", "200"}], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "20"}, {"qi", "20"}, {"qi", "70"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["「五遁绝杀」只能在战斗中使用。\n", "你的气不够，无法施展「五遁绝杀」！\n", "你的内功火候不够，难以施展「五遁绝杀」！\n", "你的真气不够，无法施展「五遁绝杀」！\n", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIC", "NOR", "WHT"], "combat_messages": %{"fail": [], "other": ["HIC "$N" HIC "使出五行遁中的「五遁绝杀」，身法"
      #                 "陡然间变得变幻莫测！\n" NOR"], "success": []}, "receive_damage_calls": [%{"formula": "10", "kind": "damage", "part": "qi", "source": None}], "resource_adds": [{"neili", "-10"}], "resource_queries": ["max_neili", "neili", "qi"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-10"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(1);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // break.c 五遁绝杀
      # 
      # #include <ansi.h>
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         string msg;
      #         int count;
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail("「五遁绝杀」只能在战斗中使用。\n");
      # 
      #         if ((int)me->query("qi") < 70)
      #                 return notify_fail("你的气不够，无法施展「五遁绝杀」！\n");
      # 
      #         if (me->query_skill("force") < 200)
      #                 return notify_fail("你的内功火候不够，难以施展「五遁绝杀」！\n");
      # 
      #         if ((int)me->query("neili") < (int)me->query("max_neili") / 2)
      #                 return notify_fail("你的真气不够，无法施展「五遁绝杀」！\n");
      # 
      #        if (! living(target))
      #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIC "$N" HIC "使出五行遁中的「五遁绝杀」，身法"
      #               "陡然间变得变幻莫测！\n" NOR;
      # 
      #         message_combatd(msg, me);
      #         count = (int)me->query_skill("five-avoid") / 30 + 2;
      #         if (count > 5 ) count = 5;
      # 
      #         while (count--)
      #         {
      #                 if (! target || (environment(target) != environment(me)) ||
      #                     ! me->is_fighting(target) ||
      #                     me->query("qi") < 20 ||
      #                     me->query("neili") < 20)
      #                 {
      #                         message_combatd(WHT "$N" WHT "的身形倏地一"
      #                                         "转，收身停住了脚步。\n" NOR, me);
      #                         break;
      #                 } else
      # 
      #                 message_combatd(WHT "$N" WHT "的身影在$n"
      #                                 WHT "身旁时隐时现 ...\n" NOR, me, target);
      #                 if (! COMBAT_D->fight(me, target))
      #                         message_combatd(WHT "但是$N" WHT "始终没有找到机会出手！\n" NOR, me);
      #                 me->receive_damage("qi", 10);
      #                 me->add("neili", -10);
      #         }
      # 
      #         me->start_busy(1);
      #         return 1;
      # }
end
