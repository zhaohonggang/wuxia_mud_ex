defmodule Kantele.Combat.Skills.Performs.XiantianGong.Shield do
  @moduledoc """
  exert「shield」（source xiantian-gong/shield.c，由 translate_perform.py 骨架生成，inherit F_CLEAN_UP）

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
      #   %{"assign_refs": [{"skill", "xiantian-gong"}], "level_gates": [{"xiantian-gong", "50"}], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你的先天功还不够深厚。\n", "你现在的真气不够。\n", "你已经在运功中了。\n"], "buff_delete": ["shield"], "call_outs": [%{"args": "me,
      #                                 skill / 2", "delay": "skill", "fn": "remove_effect"}], "callback_functions": [%{"body": "if (me->query_temp("shield"))
      #           {
      #                   me->add_temp("apply/armor", -amount);
      #                   me->delete_temp("shield");
      #                   tell_object(me, "你先天无极劲运转完一个周天，将内力收回丹田。\n");", "name": "remove_effect", "params": "object me, int amount", "return_type": "void"}], "color_codes": ["HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "$N" HIW "深深吸了一口气，双臂一振，一股浑厚的气劲登"
      #                 "时盘旋在身边四周。\n" NOR"], "success": []}, "resource_adds": [{"neili", "-100"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": false, "uses_offensive_target": false}}
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
      # // shield.c 先天无极劲
      # 
      # #include <ansi.h>
      # 
      # inherit F_CLEAN_UP;
      # 
      # void remove_effect(object me, int a_amount);
      # 
      # int exert(object me, object target)
      # {
      #         int skill;
      #         string msg;
      # 
      #         if ((int)me->query_skill("xiantian-gong", 1) < 50)
      #                 return notify_fail("你的先天功还不够深厚。\n");
      # 
      #         if ((int)me->query("neili") < 200) 
      #                 return notify_fail("你现在的真气不够。\n");
      # 
      #         if ((int)me->query_temp("shield"))
      #                 return notify_fail("你已经在运功中了。\n");
      # 
      #         skill = me->query_skill("xiantian-gong", 1);
      # 
      #         msg = HIW "$N" HIW "深深吸了一口气，双臂一振，一股浑厚的气劲登"
      #               "时盘旋在身边四周。\n" NOR;
      #         message_combatd(msg, me);
      # 
      #         me->add_temp("apply/armor", skill / 2);
      #         me->set_temp("shield", 1);
      # 
      #         me->start_call_out((: call_other, __FILE__, "remove_effect", me,
      #                               skill / 2 :), skill);
      # 
      #         me->add("neili", -100);
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
      #                 tell_object(me, "你先天无极劲运转完一个周天，将内力收回丹田。\n");
      #         }
      # }
end
