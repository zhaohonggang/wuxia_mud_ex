defmodule Kantele.Combat.Skills.FeixingShu do
  @moduledoc """
  飞星术（对照 `kungfu/skill/feixing-shu.c`）

  暗器/飞星载体：`valid_enable("throwing")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/feixing_shu/`。

  学习门槛 `valid_learn/2`（force>=50 / dodge>=40 / poison>=30 / dex>=25 / poison>=self / throwing>=self）与
  练招消耗 `practice_cost`（qi 50 / neili 48）已按 LPC 迁移（2026-10-30）。招式表沿用基类占位 TODO。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "feixing-shu"

  @impl true
  def valid_enable(usage), do: usage in ["throwing", "parry"]

  @impl true
  def valid_learn(stats, _character) do
    cond do
      Stats.skill(stats, "force") < 50 ->
        {:error, "你的内功心法火候不够，无法学飞星术。\n"}

      Stats.skill(stats, "dodge") < 40 ->
        {:error, "你的轻功火候不够，无法学习飞星术。\n"}

      Stats.skill(stats, "poison") < 30 ->
        {:error, "你的毒功火候不够，无法领悟飞星术。\n"}

      Stats.dex(stats) < 25 ->
        {:error, "你的身法不够灵巧，无法学习飞星术。\n"}

      Stats.skill(stats, "poison") < Stats.skill(stats, id()) ->
        {:error, "你的毒功水平有限，无法领悟更高深的飞星术。\n"}

      Stats.skill(stats, "throwing") < Stats.skill(stats, id()) ->
        {:error, "你的基本暗器水平有限，无法领悟更高深的飞星术。\n"}

      true ->
        :ok
    end
  end

  @doc "练招消耗：LPC practice_skill 扣 qi 50 / neili 48"
  @impl true
  def practice_cost(), do: %{qi: 50, neili: 48}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"hua" => Kantele.Combat.Skills.Performs.FeixingShu.Hua}
  end
end
