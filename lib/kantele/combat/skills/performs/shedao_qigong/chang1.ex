defmodule Kantele.Combat.Skills.Performs.ShedaoQigong.Chang1 do
  @moduledoc """
  perform「chang1」（source shedao-qigong/chang1.c，由 translate_perform.py 生成，inherit ?）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kalevala.Event
  alias Kantele.Combat.Engine
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "shedao-qigong/chang1"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "shedao-qigong")
    skill = Stats.skill(stats, "force")

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{attacker: ref(character), perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          rng: rng
        }
      })

      apply_effect(conn, character)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
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
      Stats.skill(stats, "shedao-qigong") < 60 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 300 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 200}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.apply_temp(combat, %{attack: 1, defense: 1, dodge: 1})
    character = %{character | meta: Map.put(character.meta, :combat, combat)}

    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "这里没有可供攻击的对手。\n"}
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    _stats = character.meta.stats
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 200, 1)
    result = Messages.interpolate("", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-200"}], "apply_adds": ["attack", "defense", "dodge"], "assign_refs": [{"skill", "force"}], "level_gates": [{"shedao-qigong", "60"}], "remote_damage": false, "resource_gates": [{"neili", "300"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // 唱仙法
  # 
  # #include <ansi.h>
  # 
  # int perform(object me)
  # {
  #     int skill;
  #     // string msg;
  # 
  #     if (! me->is_fighting())
  #         return notify_fail("唱仙法只能在战斗中使用。\n");
  # 
  #     if ((int)me->query_skill("shedao-qigong", 1) < 60)
  #         return notify_fail("你的蛇岛奇功不够娴熟，不会使用唱仙法。\n");
  # 
  #     if ((int)me->query("neili") < 300)
  #         return notify_fail("你已经唱得精疲力竭，内力不够了。\n");
  # 
  #     if ((int)me->query_temp("chang") >= 30)
  #         return notify_fail("你已经唱得太久了，不能再唱了。\n");
  # 
  #     skill = me->query_skill("force");
  # 
  #     me->add("neili", -200);
  # 
  #     message_combatd(HIR "只听$N" HIR "口中念念有词，顷刻"
  #                         "之间武功大进！\n" NOR, me);
  # 
  #     me->add_temp("apply/attack", 1);
  #     me->add_temp("apply/dodge", 1);
  #     me->add_temp("apply/defense", 1);
  #     me->add_temp("chang", 1);
  # 
  #     return 1;
  # }
end
