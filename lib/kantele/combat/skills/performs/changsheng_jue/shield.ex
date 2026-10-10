defmodule Kantele.Combat.Skills.Performs.ChangshengJue.Shield do
  @moduledoc """
  exert「shield」（source changsheng-jue/shield.c，由 translate_perform.py 骨架生成，inherit F_CLEAN_UP）

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
      #   %{"assign_refs": [{"skill", "force"}], "level_gates": [], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "100"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你只能用长生决来提升自己的防御力。\n", "你的内力不够。\n", "你已经在运功中了。\n"], "buff_delete": ["shield"], "call_outs": [%{"args": "me, skill * 2", "delay": "skill", "fn": "remove_effect"}], "callback_functions": [%{"body": "if (me->query_temp("shield"))
      #           {
      #                   me->add_temp("apply/armor", -amount);
      #                   me->delete_temp("shield");
      #                   tell_object(me, "你的长生决运行完毕，将内力收回丹田。\n");", "name": "remove_effect", "params": "object me, int amount", "return_type": "void"}], "color_codes": ["HIW", "NOR"], "combat_messages": %{"fail": [], "other": [], "success": []}, "receive_damage_calls": [%{"formula": "0", "kind": "damage", "part": "qi", "source": None}], "resource_adds": [{"neili", "-100"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": false, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}], "affect_by": [], "apply_adds": ["armor"], "busy_lines": ["if (me->is_fighting()) me->start_busy(2);"], "remote_damage": false, "set_flags": [], "temp_set": ["shield"]}
      #   - if (me->is_fighting()) me->start_busy(2);
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
      #         int skill;
      # 
      #         if (target != me)
      #                 return notify_fail("你只能用长生决来提升自己的防御力。\n");
      # 
      #         if ((int)me->query("neili") < 100)
      #                 return notify_fail("你的内力不够。\n");
      # 
      #         if ((int)me->query_temp("shield"))
      #                 return notify_fail("你已经在运功中了。\n");
      # 
      #         skill = me->query_skill("force");
      #         me->add("neili", -100);
      #         me->receive_damage("qi", 0);
      # 
      #         message_combatd(HIW "$N" HIW "双手平举过顶，运起长生决"
      #                         "内劲，全身笼罩在劲气之中！\n" NOR, me);
      # 
      #         me->add_temp("apply/armor", skill * 3);
      #         me->set_temp("shield", 1);
      # 
      #         me->start_call_out((: call_other, __FILE__, "remove_effect", me, skill * 2 :), skill);
      # 
      #         if (me->is_fighting()) me->start_busy(2);
      # 
      #         return 1;
      # }
      # 
      # void remove_effect(object me, int amount)
      # {
      #         if (me->query_temp("shield"))
      #         {
      #                 me->add_temp("apply/armor", -amount);
      #                 me->delete_temp("shield");
      #                 tell_object(me, "你的长生决运行完毕，将内力收回丹田。\n");
      #         }
      # }
end
