defmodule Kantele.Combat.Skills.FengleiZifa do
  @moduledoc """
  风雷子法（对照 `kungfu/skill/fenglei-zifa.c`）

  暗器载体：`valid_enable("throwing")`；
  `valid_force` 接受 基本暗器/风雷子法 共存。

  绝招实现见 `lib/kantele/combat/skills/performs/fenglei_zifa/`。

  学习门槛 `valid_learn/2`（max_neili>=500 / force>=80 / throwing>=self）与练招消耗
  `practice_cost`（qi 35 / neili 48）已按 LPC 迁移（2026-10-30）。招式表沿用基类占位 TODO。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "fenglei-zifa"

  @impl true
  def valid_enable(usage), do: usage == "throwing"

  @impl true
  def valid_force(force), do: force in ["basic-throwing", "fenglei-zifa"]

  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 500 ->
        {:error, "你的内力不够，没有办法练风雷子法。\n"}

      Stats.skill(stats, "force") < 80 ->
        {:error, "你的内功火候不够，没有办法练风雷子法。\n"}

      Stats.skill(stats, "throwing") < Stats.skill(stats, id()) ->
        {:error, "你的基本暗器水平有限，无法领会更高深的风雷子法。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili), do: max_neili
  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 35 / neili 48"
  @impl true
  def practice_cost(), do: %{qi: 35, neili: 48}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"she" => Kantele.Combat.Skills.Performs.FengleiZifa.She}
  end
end
