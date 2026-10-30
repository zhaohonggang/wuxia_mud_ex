defmodule Kantele.Combat.Skills.Sougu do
  @moduledoc """
  搜骨鹰爪功（对照 `kungfu/skill/sougu.c`）

  爪/抓法载体：`valid_enable("claw")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/sougu/`。

  学习门槛 `valid_learn/2`（force>=100 / max_neili>=600 / str>=33）与练招消耗
  `practice_cost`（qi 55 / neili 57）已按 LPC 迁移（2026-10-30）。LPC valid_learn 的「须空手」检查由 practice 流程把关；招式表沿用基类占位 TODO。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "sougu"

  @impl true
  def valid_enable(usage), do: usage in ["claw", "parry"]

  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      Stats.skill(stats, "force") < 100 ->
        {:error, "你的内功火候不够，无法学搜骨鹰爪功。\n"}

      not is_nil(max_neili) and max_neili < 600 ->
        {:error, "你的内力太弱，无法学搜骨鹰爪功。\n"}

      Stats.str(stats) < 33 ->
        {:error, "你现在的膂力太差，还无法学搜骨鹰爪功。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili), do: max_neili
  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 55 / neili 57（须空手，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 55, neili: 57}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"muyeyingyang" => Kantele.Combat.Skills.Performs.Sougu.Muyeyingyang}
  end
end
