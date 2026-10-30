defmodule Kantele.Combat.Skills.NianhuaZhi do
  @moduledoc """
  拈花指（对照 `kungfu/skill/nianhua-zhi.c`）

  指法载体：`valid_enable("finger")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/nianhua_zhi/`。

  学习门槛 `valid_learn/2`（force>=60 / max_neili>=300 / finger>=self）与练招消耗
  `practice_cost`（qi 50 / neili 64）已按 LPC 迁移（2026-10-30）。LPC valid_learn 的「须空手」检查由 practice 流程把关；招式表沿用基类占位 TODO。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "nianhua-zhi"

  @impl true
  def valid_enable(usage), do: usage in ["finger", "parry"]

  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      Stats.skill(stats, "force") < 60 ->
        {:error, "你的内功火候不够，无法学拈花指。\n"}

      not is_nil(max_neili) and max_neili < 300 ->
        {:error, "你的内力太弱，无法练拈花指。\n"}

      Stats.skill(stats, "finger") < Stats.skill(stats, id()) ->
        {:error, "你的基本指法水平有限，无法领会更高深的拈花指。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili), do: max_neili
  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 50 / neili 64（须空手，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 50, neili: 64}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"fuxue" => Kantele.Combat.Skills.Performs.NianhuaZhi.Fuxue}
  end
end
