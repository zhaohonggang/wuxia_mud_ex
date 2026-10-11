defmodule Kantele.Combat.Skills.Performs.Hamagong.Reserve do
  @moduledoc """
  exert「reserve」（source hamagong/reserve.c，由 translate_perform.py 生成，inherit F_CLEAN_UP）

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
      Stats.skill(stats, "hamagong") < 120 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 200 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
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
  #   %{"add_costs": [{"neili", "-100"}], "apply_adds": ["armor", "dispel_poison", "dodge", "parry"], "assign_refs": [{"skill", "hamagong"}], "busy_lines": ["if (me->is_fighting()) me->start_busy(2);"], "level_gates": [{"hamagong", "120"}], "remote_damage": false, "resource_gates": [{"neili", "200"}], "temp_set": ["hmg_dzjm"]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // reserve.c 蛤蟆功经脉倒转
  # 
  # #include <ansi.h>
  # 
  # inherit F_CLEAN_UP;
  # 
  # void remove_effect(object me, int a_amount);
  # 
  # int exert(object me, object target)
  # {
  #         // object weapon;
  #         int skill;
  #         string msg;
  # 
  #         if ((int)me->query_skill("hamagong", 1) < 120)
  #                 return notify_fail("你的蛤蟆功不够娴熟，不会经脉倒转。\n");
  # 
  #         if ((int)me->query("neili") < 200)
  #                 return notify_fail("你现在的真气不够。\n");
  # 
  #         if ((int)me->query_temp("hmg_dzjm"))
  #                 return notify_fail("你已经倒转经脉了。\n");
  # 
  #         skill = me->query_skill("hamagong", 1);
  #         msg = HIB "$N" HIB "忽地双手撑地倒立，逆运经脉，顿时"
  #               "内息暗生，防御力大增。\n" NOR;
  #         message_combatd(msg, me);
  # 
  #         me->add_temp("apply/dodge", skill / 3);
  #         me->add_temp("apply/parry", skill / 3);
  #         me->add_temp("apply/armor", skill / 2);
  #         me->add_temp("apply/dispel_poison", skill / 2);
  #         me->set_temp("hmg_dzjm", skill);
  # 
  #         me->add("neili", -100);
  #         if (me->is_fighting()) me->start_busy(2);
  # 
  #         return 1;
  # }
end
