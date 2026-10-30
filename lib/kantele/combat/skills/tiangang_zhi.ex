defmodule Kantele.Combat.Skills.TiangangZhi do
  @moduledoc """
  天罡指（对照 `kungfu/skill/tiangang-zhi.c`）

  指法载体：`valid_enable("finger")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/tiangang_zhi/`。

  学习门槛 `valid_learn/2`（force>=100 / max_neili>=500 / finger>=self）与练招消耗
  `practice_cost`（qi 55 / neili 51）已按 LPC 迁移（2026-10-30）。LPC valid_learn 的「须空手」检查由 practice 流程把关；招式表沿用基类占位 TODO。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "tiangang-zhi"

  @impl true
  def valid_enable(usage), do: usage in ["finger", "parry"]

  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      Stats.skill(stats, "force") < 100 ->
        {:error, "你的内功火候不够，无法学天罡指穴法。\n"}

      not is_nil(max_neili) and max_neili < 500 ->
        {:error, "你的内力太弱，无法练天罡指穴法。\n"}

      Stats.skill(stats, "finger") < Stats.skill(stats, id()) ->
        {:error, "你的基本指法太差，无法领会更高深的天罡指穴法。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili), do: max_neili
  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 55 / neili 51（须空手，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 55, neili: 51}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"ling" => Kantele.Combat.Skills.Performs.TiangangZhi.Ling}
  end
end
