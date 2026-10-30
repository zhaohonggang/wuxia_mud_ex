defmodule Kantele.Combat.Skills.JiuquJian do
  @moduledoc """
  九曲剑法（对照 `kungfu/skill/jiuqu-jian.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/jiuqu_jian/`。

  学习门槛 `valid_learn/2`（max_neili>=300 / force>=100 / sword>=60 / sword>=jiuqu-jian）与
  练招消耗 `practice_cost`（LPC 扣 qi 40 / neili 50，须持剑）已按 LPC 迁移（2026-10-30）。
  LPC 的须持剑（weapon skill_type=="sword"，valid_learn 与 practice_skill 均检查）由 practice 流程把关，未写入 `valid_learn`；招式表沿用基类占位 TODO。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "jiuqu-jian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "parry"]

  # LPC valid_learn 要求 max_neili>=300 / force>=100 / sword>=60 / sword>=jiuqu-jian
  # （须持剑检查 weapon skill_type=="sword" 沿用 practice 流程把关，未在此建模）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 300 ->
        {:error, "你的内力不够，没有办法练九曲剑法。\n"}

      Stats.skill(stats, "force") < 100 ->
        {:error, "你的内功火候太浅。\n"}

      Stats.skill(stats, "sword") < 60 ->
        {:error, "你的基本剑法火候不够，无法学习九曲剑法。\n"}

      Stats.skill(stats, "sword") < Stats.skill(stats, id()) ->
        {:error, "你的基本剑法火候有限，无法领会更高深的九曲剑法。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 40 / neili 50（须持剑，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 40, neili: 50}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"wan" => Kantele.Combat.Skills.Performs.JiuquJian.Wan}
  end
end
