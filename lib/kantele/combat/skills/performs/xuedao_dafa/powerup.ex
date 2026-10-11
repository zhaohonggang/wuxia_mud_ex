defmodule Kantele.Combat.Skills.Performs.XuedaoDafa.Powerup do
  @moduledoc """
  exert「powerup」（source xuedao-dafa/powerup.c，由 translate_perform.py 生成，inherit F_CLEAN_UP）

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
    with :ok <- check_resources(character),
         :ok <- check_other(character) do
      :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 150 -> {:error, "你的内力不够。\n"}
      true -> :ok
    end
  end

  defp check_other(character) do
    # TODO(migrate) 其它门槛（战斗/临时状态/道具等）需人工核对：
    #   {:error, "你只能用血刀大法来提升自己的战斗力。\n"}
    :ok

  end

  defp apply_effect(conn, character) do
    # 无条件攻击方效果：消耗/Busy/Apply/暗器数量 + 前置广播
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 100}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}], "apply_adds": ["attack", "damage", "defense"], "assign_refs": [{"skill", "xuedao-dafa"}], "busy_lines": ["me->start_busy(1 + random(3));"], "remote_damage": false, "resource_gates": [{"neili", "150"}], "temp_set": ["powerup"]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # 
  # inherit F_CLEAN_UP;
  # 
  # void remove_effect(object me, int amount);
  # 
  # int exert(object me, object target)
  # {
  #         object weapon;
  #         int skill;
  # 
  #         if (target != me)
  #                 return notify_fail("你只能用血刀大法来提升自己的战斗力。\n");
  # 
  #         if ((int)me->query("neili") < 150)
  #                 return notify_fail("你的内力不够。\n");
  # 
  #         if ((int)me->query_temp("powerup"))
  #                 return notify_fail("你已经在运功中了。\n");
  # 
  #         skill = me->query_skill("xuedao-dafa", 1);
  # 
  #         me->add("neili", -100);
  #         me->receive_damage("qi", 0);
  # 
  #         message_combatd(HIR "$N" HIR "仰天一声狂哮，全身骨骼爆响，真气荡漾，杀"
  #                         "气弥漫，气势迫人。\n" NOR, me);
  # 
  #         if (objectp(weapon = me->query_temp("weapon")) &&
  #            (string)weapon->query("skill_type") == "blade" &&
  #            me->query_skill_mapped("blade") == "xuedao-dafa")
  #         {
  #             message_combatd(HIR "$N" HIR "嗔目狞笑，手中" + weapon->name() +
  #                                 HIR "顿时漾起一道血光，漫起无边杀意。\n" NOR, me);
  #         }
  # 
  #         me->add_temp("apply/attack", skill / 3);
  #         me->add_temp("apply/defense", skill / 3);
  #         me->add_temp("apply/damage", skill / 3);
  #         me->set_temp("powerup", 1);
  # 
  #         me->start_call_out((: call_other, __FILE__, "remove_effect",
  #                               me, skill / 3, skill / 3 :), skill);
  #         if (me->is_fighting())
  #             me->start_busy(1 + random(3));
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
  #                 me->add_temp("apply/damage", -amount);
  #                 me->delete_temp("powerup");
  #                 tell_object(me, "你的血刀大法运行完毕，将内力收回丹田。\n");
  #         }
  # }
end
