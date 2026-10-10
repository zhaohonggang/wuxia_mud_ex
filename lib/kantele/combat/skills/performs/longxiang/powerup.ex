defmodule Kantele.Combat.Skills.Performs.Longxiang.Powerup do
  @moduledoc """
  exert「powerup」（source longxiang/powerup.c，由 translate_perform.py 骨架生成，inherit F_CLEAN_UP）

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
      #   %{"assign_refs": [{"lvl", "longxiang-gong"}, {"skill", "force"}], "level_gates": [], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "500"}], "var_gates": [{"layer", "3"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你只能提升自己的战斗力。\n", "你龙象般若功修为不够，难以运功。\n", "你目前的真气不够。\n", "你已经在运功中了。\n"], "buff_delete": ["powerup"], "call_outs": [%{"args": "me, skill / 3", "delay": "skill", "fn": "remove_effect"}], "callback_functions": [%{"body": "if ((int)me->query_temp("powerup"))
      #           {
      #                   me->add_temp("apply/attack", -(amount - (layer * 15)));
      #                   me->add_temp("apply/parry", -amount);
      #                   me->add_temp", "name": "remove_effect", "params": "object me, int amount", "return_type": "void"}], "color_codes": ["HIY", "NOR"], "combat_messages": %{"fail": [], "other": [], "success": []}, "resource_adds": [{"neili", "-100"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": false, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}], "affect_by": [], "apply_adds": ["attack", "dodge", "parry"], "busy_lines": ["if (me->is_fighting()) me->start_busy(3);"], "remote_damage": false, "set_flags": [], "temp_set": ["powerup"]}
      #   - if (me->is_fighting()) me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # 
      # inherit F_CLEAN_UP;
      # 
      # void remove_effect(object me, int amount);
      # 
      # int exert(object me, object target)
      # {
      #         int skill, lvl, layer;
      # 
      #         lvl = me->query_skill("longxiang-gong", 1);
      #         layer = lvl / 30;
      # 
      #         if (layer > 13) layer = 13;
      # 
      #         if (target != me)
      #                 return notify_fail("你只能提升自己的战斗力。\n");
      # 
      #         if (layer < 3)
      #                 return notify_fail("你龙象般若功修为不够，难以运功。\n");
      # 
      #         if ((int)me->query("neili") < 500)
      #                 return notify_fail("你目前的真气不够。\n");
      # 
      #         if ((int)me->query_temp("powerup"))
      #                 return notify_fail("你已经在运功中了。\n");
      # 
      #         skill = me->query_skill("force");
      # 
      #         message_vision(HIY "$N" HIY "运足龙象般若功第" + chinese_number(layer) +
      #                        "层功力，全身骨骼节节暴响，罡气向四周扩散开来！\n" NOR, me);
      # 
      #         me->add_temp("apply/attack", (skill / 3) + (layer * 15));
      #         me->add_temp("apply/parry", skill / 3);
      #         me->add_temp("apply/dodge", skill / 3);
      #         me->set_temp("powerup", 1);
      #         me->add("neili", -100);
      # 
      #         me->start_call_out((: call_other, __FILE__, "remove_effect",
      #                               me, skill / 3 :), skill);
      # 
      #         if (me->is_fighting()) me->start_busy(3);
      # 
      #         return 1;
      # }
      # /*
      # void remove_effect(object me, int amount)
      # {
      #         if ((int)me->query_temp("powerup"))
      #         {
      #                 me->add_temp("apply/attack", -(amount - (layer * 15)));
      #                 me->add_temp("apply/parry", -amount);
      #                 me->add_temp("apply/dodge", -amount);
      #                 me->delete_temp("powerup");
      #                 tell_object(me, "你的龙象般若功运行完毕，将内力收回丹田。\n");
      #         }
      # }*/
end
