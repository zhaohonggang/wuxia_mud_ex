defmodule Kantele.Combat.Skills.SongshanJian do
  @moduledoc """
  嵩山剑法（对照 `kungfu/skill/songshan-jian.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/songshan_jian/`。

  学习门槛 `valid_learn/2`（max_neili>=100 / sword>=15 / sword>=songshan-jian）与
  练招消耗 `practice_cost`（LPC 扣 qi 45 / neili 30，须持剑）已按 LPC 迁移（2026-10-30）。
  LPC 的「须持剑（weapon skill_type=="sword"）」检查未在 `valid_learn` 建模
  （由 practice 流程把关），招式表沿用基类占位 TODO。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "songshan-jian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "parry"]

  # LPC valid_learn 要求 max_neili>=100 / sword>=15 / sword>=songshan-jian
  # （须持剑检查 weapon skill_type=="sword" 沿用 practice 流程把关，未在此建模）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 100 ->
        {:error, "你目前的内力修为不够，没有办法练嵩山剑法。\n"}

      Stats.skill(stats, "sword") < 15 ->
        {:error, "你的基本剑法火候太浅，没有办法练嵩山剑法。\n"}

      Stats.skill(stats, "sword") < Stats.skill(stats, id()) ->
        {:error, "你的基本剑法火候有限，无法领会更高深的绝情剑法。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 45 / neili 30（须持剑，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 45, neili: 30}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"meng" => Kantele.Combat.Skills.Performs.SongshanJian.Meng}
  end
end
