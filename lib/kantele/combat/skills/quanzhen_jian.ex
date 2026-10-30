defmodule Kantele.Combat.Skills.QuanzhenJian do
  @moduledoc """
  全真剑法（对照 `kungfu/skill/quanzhen-jian.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/quanzhen_jian/`。

  学习门槛 `valid_learn/2`（force>=150 / max_neili>=1000 / sword>=100 /
  sword>=quanzhen-jian）与练招消耗 `practice_cost`（LPC 扣 qi 55 / neili 53，须持剑）
  已按 LPC 迁移（2026-10-30）。LPC 的「须持剑（weapon skill_type=="sword"）」检查
  未在 `valid_learn` 建模（由 practice 流程把关），招式表沿用基类占位 TODO。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "quanzhen-jian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "parry"]

  # LPC valid_learn 要求 force>=150 / max_neili>=1000 / sword>=100 / sword>=quanzhen-jian
  # （须持剑检查 weapon skill_type=="sword" 沿用 practice 流程把关，未在此建模）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      Stats.skill(stats, "force") < 150 ->
        {:error, "你的内功火候不足，无法学习全真剑法。\n"}

      not is_nil(max_neili) and max_neili < 1000 ->
        {:error, "你的内力修为太差，无法学习全真剑法。\n"}

      Stats.skill(stats, "sword") < 100 ->
        {:error, "你的基本剑法修为不够，无法学习全真剑法。\n"}

      Stats.skill(stats, "sword") < Stats.skill(stats, id()) ->
        {:error, "你的基本剑法水平有限，无法领会更高深的全真剑法。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 55 / neili 53（须持剑，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 55, neili: 53}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{
      "chan" => Kantele.Combat.Skills.Performs.QuanzhenJian.Chan,
      "ding" => Kantele.Combat.Skills.Performs.QuanzhenJian.Ding,
      "hua" => Kantele.Combat.Skills.Performs.QuanzhenJian.Hua,
      "lian" => Kantele.Combat.Skills.Performs.QuanzhenJian.Lian
    }
  end
end
