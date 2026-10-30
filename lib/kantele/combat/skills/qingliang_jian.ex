defmodule Kantele.Combat.Skills.QingliangJian do
  @moduledoc """
  清凉剑法（对照 `kungfu/skill/qingliang-jian.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/qingliang_jian/`。

  学习门槛 `valid_learn/2`（max_neili>=500 / shaolin-xinfa>=50 / sword>=50）与
  练招消耗 `practice_cost`（LPC 扣 qi 35（不耗内力），须持剑）已按 LPC 迁移（2026-10-30）。
  LPC 的「须持剑（weapon skill_type=="sword"）」检查未在 `valid_learn` 建模
  （由 practice 流程把关），招式表沿用基类占位 TODO。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "qingliang-jian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "parry"]

  # LPC valid_learn 要求 max_neili>=500 / shaolin-xinfa>=50 / sword>=50
  # （须持剑检查 weapon skill_type=="sword" 沿用 practice 流程把关，未在此建模）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 500 ->
        {:error, "你的内力不够。\n"}

      Stats.skill(stats, "shaolin-xinfa") < 50 ->
        {:error, "你的少林心法火候太浅。\n"}

      Stats.skill(stats, "sword") < 50 ->
        {:error, "你的基本剑法火候尚浅。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 35（不耗内力，须持剑，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 35, neili: 0}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"ming" => Kantele.Combat.Skills.Performs.QingliangJian.Ming}
  end
end
