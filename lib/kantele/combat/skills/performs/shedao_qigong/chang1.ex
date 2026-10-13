defmodule Kantele.Combat.Skills.Performs.ShedaoQigong.Chang1 do
  @moduledoc """
  perform「chang1」（source shedao-qigong/chang1.c，由 translate_perform.py 生成，inherit ?）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @perform_id "shedao-qigong/chang1"
  @move_name "「唱仙法」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "shedao-qigong")
    skill = Stats.skill(stats, "force")

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character) do
      apply_effect(conn, character, skill, rng)
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
         :ok <- check_resources(character),
         :ok <- check_fighting(character),
         :ok <- check_chang_limit(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "shedao-qigong") < 60 -> {:error, "你的蛇岛奇功不够娴熟，不会使用唱仙法。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 300 -> {:error, "你已经唱得精疲力竭，内力不够了。\n"}
      true -> :ok
    end
  end

  defp check_fighting(character) do
    combat = character.meta.combat

    if Combat.fighting?(combat) do
      :ok
    else
      {:error, "唱仙法只能在战斗中使用。\n"}
    end
  end

  defp check_chang_limit(character) do
    # LPC: query_temp("chang") >= 30
    chang = Map.get(character.meta.temp, "chang", 0)

    if chang >= 30 do
      {:error, "你已经唱得太久了，不能再唱了。\n"}
    else
      :ok
    end
  end

  defp apply_effect(conn, character, _skill, _rng) do
    # LPC: neili -200; attack/dodge/defense +1; chang +1; broadcast
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 200}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}

    combat = character.meta.combat
    combat = Combat.apply_temp(combat, %{attack: 1, defense: 1, dodge: 1})

    combat =
      Map.update(combat, :temp, %{}, fn temp ->
        Map.update(temp, "chang", 0, &(&1 + 1))
      end)

    character = %{character | meta: Map.put(character.meta, :combat, combat)}

    Broadcast.publish(conn, "只听$N口中念念有词，顷刻之间武功大进！", n1: character.name)

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end
end
