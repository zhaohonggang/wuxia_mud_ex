defmodule Kantele.Combat.Skills.Performs.HuntianBaojian.Powerup do
  @moduledoc """
  exert「powerup」（source huntian-baojian/powerup.c，由 translate_perform.py 骨架生成，inherit F_CLEAN_UP）

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
      #   %{"assign_refs": [{"skill", "force"}], "level_gates": [], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "150"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你只能用浑天宝鉴来提升自己的战斗力。\n", "你的内力不够。\n", "你已经在运功中了。\n"], "buff_delete": ["powerup"], "call_outs": [%{"args": "me, skill / 2", "delay": "skill", "fn": "remove_effect"}], "callback_functions": [%{"body": "if (me->query_temp("powerup"))
      #           {
      #                   me->add_temp("apply/attack", -amount);
      #                   me->add_temp("apply/defense", -amount);
      #                   me->delete_temp("powerup");
      #       ", "name": "remove_effect", "params": "object me, int amount", "return_type": "void"}], "color_codes": ["CYN", "HIB", "HIR", "HIW", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": [], "success": []}, "receive_damage_calls": [%{"formula": "0", "kind": "damage", "part": "qi", "source": None}], "resource_adds": [{"neili", "-100"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": false, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}], "affect_by": [], "apply_adds": ["attack", "defense"], "busy_lines": ["me->start_busy(3);"], "remote_damage": false, "set_flags": [], "temp_set": ["powerup"]}
      #   - me->start_busy(3);
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
      # string *force_name = ({ NOR + HIB "靛沧海", HIY "金晨曦",
      #                         HIR "血穹苍", NOR + CYN "玄宇宙", }); 
      # 
      # void remove_effect(object me, int amount);
      # 
      # int exert(object me, object target)
      # {
      #         int skill;
      #         string name;
      #         name = force_name[random(sizeof(force_name))];
      # 
      #         if (target != me)
      #                 return notify_fail("你只能用浑天宝鉴来提升自己的战斗力。\n");
      # 
      #         if ((int)me->query("neili") < 150)
      #                 return notify_fail("你的内力不够。\n");
      # 
      #         if ((int)me->query_temp("powerup"))
      #                 return notify_fail("你已经在运功中了。\n");
      # 
      #         skill = me->query_skill("force");
      #         me->add("neili", -100);
      #         me->receive_damage("qi", 0);
      # 
      #         message_combatd(HIW "$N" HIW "微一凝神，运起浑天宝鉴之「" + name +
      #                         HIW "」心法，一股气流顿将你震退数步。\n" NOR, me);
      # 
      #         me->add_temp("apply/attack", skill / 2);
      #         me->add_temp("apply/defense", skill / 2);
      #         me->set_temp("powerup", 1);
      # 
      #         me->start_call_out((: call_other, __FILE__, "remove_effect",
      #                               me, skill / 2 :), skill);
      # 
      #         if (me->is_fighting())
      #                 me->start_busy(3);
      # 
      #         return 1;
      # }
      # 
      # void remove_effect(object me, int amount)
      # {
      #         if (me->query_temp("powerup"))
      #         {
      #                 me->add_temp("apply/attack", -amount);
      #                 me->add_temp("apply/defense", -amount);
      #                 me->delete_temp("powerup");
      #                 tell_object(me, "你的浑天宝鉴运行完毕，将内力收回丹田。\n");
      #         }
      # }
end
