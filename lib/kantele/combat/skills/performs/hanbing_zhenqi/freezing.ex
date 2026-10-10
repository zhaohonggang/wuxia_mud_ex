defmodule Kantele.Combat.Skills.Performs.HanbingZhenqi.Freezing do
  @moduledoc """
  exert「寒冰真气」（source hanbing-zhenqi/freezing.c，由 translate_perform.py 骨架生成，inherit F_CLEAN_UP）

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
      #   %{"assign_refs": [{"skill", "hanbing-zhenqi"}], "level_gates": [], "map_gates": [], "prepared_gates": [], "resource_gates": [{"con", "34"}, {"max_neili", "2200"}, {"neili", "1000"}], "var_gates": [{"skill", "140"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所学的内功中没有这种功能。\n", "你现在正在施展", "你的先天根骨不足，无法施展", "你的寒冰真气不够，难以施展", "你的内力修为不足，难以施展", "你现在尚未曾运功，难以施展", "你目前的内力不够，难以施展"], "buff_delete": ["freezing"], "call_outs": [%{"args": "me, skill", "delay": "skill", "fn": "remove_effect"}], "callback_functions": [%{"body": "if (me->query_temp("freezing"))
      #           {
      #                   me->delete_temp("freezing");
      #                   tell_object(me, "你的" FRE "运行完毕，将内力收回丹田。\n");", "name": "remove_effect", "params": "object me", "return_type": "void"}], "color_codes": ["HIW", "NOR"], "combat_messages": %{"fail": [], "other": [], "success": []}, "resource_adds": [{"neili", "-300"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": false, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-300"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(3);"], "remote_damage": false, "set_flags": [], "temp_set": ["freezing"]}
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # inherit F_CLEAN_UP;
      # 
      # #define FRE "「" HIW "寒冰真气" NOR "」"
      # 
      # void remove_effect(object me);
      # 
      # int exert(object me, object target)
      # {
      #         int skill;
      # 
      #         if (userp(me) && ! me->query("can_perform/hanbing-zhenqi/freezing"))
      #                 return notify_fail("你所学的内功中没有这种功能。\n");
      # 
      #         if ((int)me->query_temp("freezing"))
      #                 return notify_fail("你现在正在施展" FRE "。\n");
      # 
      #         if (target != me)
      #                 return notify_fail(FRE "只能对自己使用。\n");
      # 
      #         skill = me->query_skill("hanbing-zhenqi", 1);
      # 
      #         if (me->query("con") < 34)
      #                 return notify_fail("你的先天根骨不足，无法施展" FRE "。\n");
      # 
      #         if (skill < 140)
      #                 return notify_fail("你的寒冰真气不够，难以施展" FRE "。\n");
      # 
      #         if ((int)me->query("max_neili") < 2200)
      #                 return notify_fail("你的内力修为不足，难以施展" FRE "。\n");
      # 
      #         if (! me->query_temp("powerup"))
      #                 return notify_fail("你现在尚未曾运功，难以施展" FRE "。\n");
      # 
      #         if ((int)me->query("neili") < 1000)
      #                 return notify_fail("你目前的内力不够，难以施展" FRE "。\n");
      # 
      #         me->add("neili", -300);
      # 
      #         message_combatd(HIW "$N" HIW "一声冷笑，体内寒冰真气迅速疾转数个周"
      #                         "天，将力聚于掌心。\n" NOR, me);
      #         me->set_temp("freezing", 1);
      # 
      #         me->start_call_out((: call_other, __FILE__, "remove_effect",
      #                               me, skill :), skill);
      #         if (me->is_fighting())
      #                 me->start_busy(3);
      # 
      #         return 1;
      # }
      # 
      # void remove_effect(object me)
      # {
      #         if (me->query_temp("freezing"))
      #         {
      #                 me->delete_temp("freezing");
      #                 tell_object(me, "你的" FRE "运行完毕，将内力收回丹田。\n");
      #         }
      # }
end
