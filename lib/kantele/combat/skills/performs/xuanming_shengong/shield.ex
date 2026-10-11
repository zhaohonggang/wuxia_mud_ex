defmodule Kantele.Combat.Skills.Performs.XuanmingShengong.Shield do
  @moduledoc """
  exert「shield」（source xuanming-shengong/shield.c，由 translate_perform.py 生成，inherit F_CLEAN_UP）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
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
    with :ok <- check_levels(character),
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "xuanming-shengong") < 100 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 100 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 100}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 2)
    character = %{character | meta: Map.put(character.meta, :combat, combat)}

    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}], "apply_adds": ["armor", "strike"], "assign_refs": [{"skill", "xuanming-shengong"}], "busy_lines": ["if (me->is_fighting()) me->start_busy(2);"], "level_gates": [{"xuanming-shengong", "100"}], "remote_damage": false, "resource_gates": [{"neili", "100"}], "temp_set": ["shield"]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // shield.c 护体神功
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
  #                 return notify_fail("你只能用玄冥神功来提升自己的防御力。\n");
  # 
  #         if ((int)me->query("neili") < 100)
  #                 return notify_fail("你的内力不够。\n");
  # 
  #         if ((int)me->query_skill("xuanming-shengong", 1) < 100)
  #                 return notify_fail("你的玄冥神功修为不够。\n");
  # 
  #         if ((int)me->query_temp("shield"))
  #                 return notify_fail("你已经在运功中了。\n");
  # 
  #         skill = me->query_skill("xuanming-shengong", 1);
  #         me->add("neili", -100);
  #         me->receive_damage("qi", 0);
  # 
  #         message_combatd(HIW "$N" HIW "深深吸了一口气，缓缓吐出，一股白烟"
  #                         "冉冉透体而出，盘旋笼罩了全身。\n" NOR, me);
  # 
  #         me->add_temp("apply/armor", skill / 2);
  #         me->add_temp("apply/strike", skill / 8);
  #         me->set_temp("shield", 1);
  # 
  #         me->start_call_out((: call_other, __FILE__, "remove_effect", me, skill / 2 :), skill);
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
  #                 me->add_temp("apply/strike", -amount / 4);
  #                 me->delete_temp("shield");
  #                 tell_object(me, "你的玄冥神功运行完毕，将内力收回丹田。\n");
  #         }
  # }
end
