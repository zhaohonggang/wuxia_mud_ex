defmodule Kantele.Combat.Skills.DachengFosuo do
  @moduledoc """
  大乘佛索（对照 `kungfu/skill/dacheng-fosuo.c`）

  鞭法载体：`valid_enable("whip")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/dacheng_fosuo/`。

  学习门槛 `valid_learn/2`（max_neili>=1000 / shaolin-xinfa>=80）与
  练招消耗 `practice_cost`（LPC 扣 qi 90 / neili 90，须持鞭）已按 LPC 迁移（2026-10-30）。
  LPC 的「须持鞭（weapon skill_type=="whip"）」检查未在 `valid_learn` 建模
  （由 practice 流程把关），招式表沿用基类占位 TODO。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "dacheng-fosuo"

  @impl true
  def valid_enable(usage), do: usage in ["whip", "parry"]

  # LPC valid_learn 要求 max_neili>=1000 / shaolin-xinfa>=80（须持鞭检查由 practice 流程把关）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 1000 ->
        {:error, "你的内力修为不足，没有办法练大乘佛索。\n"}

      Stats.skill(stats, "shaolin-xinfa") < 80 ->
        {:error, "你的少林心法火候太浅。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 90 / neili 90（须持鞭，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 90, neili: 90}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"chanrao" => Kantele.Combat.Skills.Performs.DachengFosuo.Chanrao}
  end
end
