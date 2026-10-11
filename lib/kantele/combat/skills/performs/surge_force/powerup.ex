defmodule Kantele.Combat.Skills.Performs.SurgeForce.Powerup do
  @moduledoc """
  exert「powerup」（source surge-force/powerup.c，由 translate_perform.py 生成，inherit F_CLEAN_UP）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView

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
  defp check_gates(character), do: check_resources(character)

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
  #   %{"add_costs": [{"neili", "-200"}], "apply_adds": ["attack", "defense", "unarmed_damage"], "assign_refs": [{"skill", "surge-force"}], "busy_lines": ["if (me->is_fighting()) me->start_busy(1 + random(3));"], "remote_damage": false, "resource_gates": [{"neili", "500"}], "temp_set": ["powerup"]}

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
