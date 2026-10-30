defmodule Kantele.Combat.Skills.DaliChu do
  @moduledoc """
  大力锄法（对照 `kungfu/skill/dali-chu.c`）

  锄/锤法载体：`valid_enable("hammer")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/dali_chu/`。

  学习门槛 `valid_learn/2`（max_neili>=300 / force>=30 / hammer>=20 / hammer>=dali-chu）与
  练招消耗 `practice_cost`（LPC 扣 qi 35 / neili 40，须持锤）已按 LPC 迁移（2026-10-30）。
  LPC 的「须持锤（weapon skill_type=="hammer"）」检查未在 `valid_learn` 建模
  （由 practice 流程把关），招式表沿用基类占位 TODO。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "dali-chu"

  @impl true
  def valid_enable(usage), do: usage in ["hammer", "parry"]

  # LPC valid_learn 要求 max_neili>=300 / force>=30 / hammer>=20 / hammer>=dali-chu（须持锤检查由 practice 流程把关）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 300 ->
        {:error, "你的内力修为不够，难以修炼无上大力杵。\n"}

      Stats.skill(stats, "force") < 30 ->
        {:error, "你的内功火候太浅，难以修炼无上大力杵。\n"}

      Stats.skill(stats, "hammer") < 20 ->
        {:error, "你的基本锤法不够，难以修炼无上大力杵。\n"}

      Stats.skill(stats, "hammer") < Stats.skill(stats, id()) ->
        {:error, "你的基本锤法水平有限，无法领会更高深的无上大力杵。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 35 / neili 40（须持锤，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 35, neili: 40}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"hong" => Kantele.Combat.Skills.Performs.DaliChu.Hong}
  end
end
