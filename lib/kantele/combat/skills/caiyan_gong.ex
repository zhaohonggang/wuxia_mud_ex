defmodule Kantele.Combat.Skills.CaiyanGong do
  @moduledoc """
  彩云功（对照 `kungfu/skill/caiyan-gong.c`）

  棍/杖法载体：`valid_enable("club")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/caiyan_gong/`。

  学习门槛 `valid_learn/2`（max_neili>=250 / force>=50 / dodge>=caiyan-gong / club>=caiyan-gong）与
  练招消耗 `practice_cost`（LPC 扣 qi 62 / neili 61，须持棍）已按 LPC 迁移（2026-10-30）。
  LPC 的「须持棍（weapon skill_type=="club"）」检查未在 `valid_learn` 建模
  （由 practice 流程把关），招式表沿用基类占位 TODO。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "caiyan-gong"

  @impl true
  def valid_enable(usage), do: usage in ["club", "parry"]

  # LPC valid_learn 要求 max_neili>=250 / force>=50 / dodge>=self / club>=self（须持棍检查由 practice 流程把关）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 250 ->
        {:error, "你的内力不够。\n"}

      Stats.skill(stats, "force") < 50 ->
        {:error, "你的内功火候太浅。\n"}

      Stats.skill(stats, "dodge") < Stats.skill(stats, id()) ->
        {:error, "你的基本轻功水平有限，无法领会更高深的采燕功。\n"}

      Stats.skill(stats, "club") < Stats.skill(stats, id()) ->
        {:error, "你的基本棍法水平有限，无法领会更高深的采燕功。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 62 / neili 61（须持棍，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 62, neili: 61}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"huan" => Kantele.Combat.Skills.Performs.CaiyanGong.Huan}
  end
end
