defmodule Kantele.Combat.Skills.Performs.SurgeForce.Powerup do
  @moduledoc """
  exert「powerup」（source surge-force/powerup.c，由 translate_perform.py 骨架生成，inherit F_CLEAN_UP）

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
      #   %{"assign_refs": [{"skill", "surge-force"}], "level_gates": [], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "500"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你只能用怒海狂涛提升自己的战斗力。\n", "你的内力不够。\n", "你已经在运功中了。\n"], "buff_delete": ["powerup"], "call_outs": [%{"args": "me, skill", "delay": "skill", "fn": "remove_effect"}], "callback_functions": [%{"body": "if (me->query_temp("powerup"))
      #           {
      #                   me->add_temp("apply/attack", -(skill * 2 / 5));
      #                   me->add_temp("apply/defense", -(skill * 2 / 5));
      #                   me->add_temp("", "name": "remove_effect", "params": "object me, int skill", "return_type": "void"}], "color_codes": ["HIC", "NOR"], "combat_messages": %{"fail": [], "other": [], "success": []}, "receive_damage_calls": [%{"formula": "0", "kind": "damage", "part": "qi", "source": None}], "resource_adds": [{"neili", "-200"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": false, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-200"}], "affect_by": [], "apply_adds": ["attack", "defense", "unarmed_damage"], "busy_lines": ["if (me->is_fighting()) me->start_busy(1 + random(3));"], "remote_damage": false, "set_flags": [], "temp_set": ["powerup"]}
      #   - if (me->is_fighting()) me->start_busy(1 + random(3));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // powerup.c
      # 
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
      #                 return notify_fail("你只能用怒海狂涛提升自己的战斗力。\n");
      # 
      #         if ((int)me->query("neili") < 500)
      #                 return notify_fail("你的内力不够。\n");
      # 
      #         if ((int)me->query_temp("powerup"))
      #                 return notify_fail("你已经在运功中了。\n");
      # 
      #         skill = me->query_skill("surge-force", 1);
      # 
      #         me->add("neili", -200);
      #         me->receive_damage("qi", 0);
      # 
      #         message_combatd(HIC "$N" HIC"一声长啸，激起一阵狂风，气"
      #                         "浪翻翻滚滚，向两旁散开。\n霎时之间，便"
      #                         "似长风动起，气云聚合，天地渺然，有如海"
      #                         "浪滔滔。\n" NOR, me);
      # 
      #         me->add_temp("apply/attack", skill * 2 / 5);
      #         me->add_temp("apply/defense", skill * 2 / 5);
      #         me->add_temp("apply/unarmed_damage", skill / 5);
      #         me->set_temp("powerup", 1);
      #         me->start_call_out((: call_other, __FILE__, "remove_effect", me, skill :), skill);
      #         if (me->is_fighting()) me->start_busy(1 + random(3));
      #         return 1;
      # }
      # 
      # void remove_effect(object me, int skill)
      # {
      #         if (me->query_temp("powerup"))
      #         {
      #                 me->add_temp("apply/attack", -(skill * 2 / 5));
      #                 me->add_temp("apply/defense", -(skill * 2 / 5));
      #                 me->add_temp("apply/unarmed_damage", -(skill / 5));
      #                 me->delete_temp("powerup");
      #                 tell_object(me, "你的怒海狂涛运行完毕，将内力收回丹田。\n");
      #         }
      # }
end
