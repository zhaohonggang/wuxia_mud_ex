defmodule Kantele.Combat.Skills.JingyueBifa do
  @moduledoc """
  惊月笔法（对照 `kungfu/skill/jingyue-bifa.c`）

  笔/匕首法载体：`valid_enable("dagger")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/jingyue_bifa/`。

  学习门槛 `valid_learn/2`（max_neili>=100 / dagger>=self）与练招消耗
  `practice_cost`（qi 45 / neili 42）已按 LPC 迁移（2026-10-30）。LPC valid_learn 的「须持短兵」检查由 practice 流程把关；招式表沿用基类占位 TODO。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "jingyue-bifa"

  @impl true
  def valid_enable(usage), do: usage in ["dagger", "parry"]

  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 100 ->
        {:error, "你的内力修为不够。\n"}

      Stats.skill(stats, "dagger") < Stats.skill(stats, id()) ->
        {:error, "你的基本短兵水平有限，无法领会更高深的惊月笔法。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili), do: max_neili
  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 45 / neili 42（须持短兵，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 45, neili: 42}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"ci" => Kantele.Combat.Skills.Performs.JingyueBifa.Ci}
  end
end
