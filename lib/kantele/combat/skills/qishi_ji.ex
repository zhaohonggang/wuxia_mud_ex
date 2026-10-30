defmodule Kantele.Combat.Skills.QishiJi do
  @moduledoc """
  齐氏戟法（对照 `kungfu/skill/qishi-ji.c`）

  戟/棍法载体：`valid_enable("club")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/qishi_ji/`。

  学习门槛 `valid_learn/2`（max_neili>=100 / force>=30 / club>=self）与练招消耗
  `practice_cost`（qi 70 / neili 40）已按 LPC 迁移（2026-10-30）。须持戟检查由 practice 流程把关；LPC 重复行已合并，末门文案 verbatim「基本剑法」保真不修；招式表沿用基类占位 TODO。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "qishi-ji"

  @impl true
  def valid_enable(usage), do: usage in ["club", "parry"]

  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 100 ->
        {:error, "你的内力不够。\n"}

      Stats.skill(stats, "force") < 30 ->
        {:error, "你的内功火候不够。\n"}

      Stats.skill(stats, "club") < Stats.skill(stats, id()) ->
        {:error, "你的基本剑法水平有限，无法领会更高深的圣骑士戟。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili), do: max_neili
  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 70 / neili 40（须持戟，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 70, neili: 40}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{
      "chong" => Kantele.Combat.Skills.Performs.QishiJi.Chong,
      "juan" => Kantele.Combat.Skills.Performs.QishiJi.Juan
    }
  end
end
