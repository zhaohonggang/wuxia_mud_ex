defmodule Kantele.Combat.Skills.DuanjiaSword do
  @moduledoc """
  段家剑（对照 `kungfu/skill/duanjia-sword.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/duanjia_sword/`。

  学习门槛 `valid_learn/2`（max_neili>=100 / duanshi-xinfa>=20 / sword>=duanjia-sword）与
  练招消耗 `practice_cost`（LPC 扣 qi 45 / neili 36，须持剑）已按 LPC 迁移（2026-10-30）。
  LPC 的「须持剑（weapon skill_type=="sword"）」检查未在 `valid_learn` 建模
  （由 practice 流程把关），招式表沿用基类占位 TODO。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "duanjia-sword"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "parry"]

  # LPC valid_learn 要求 max_neili>=100 / duanshi-xinfa>=20 / sword>=duanjia-sword（须持剑检查由 practice 流程把关）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 100 ->
        {:error, "你的内力不够。\n"}

      Stats.skill(stats, "duanshi-xinfa") < 20 ->
        {:error, "你的段氏心法火候太浅。\n"}

      Stats.skill(stats, "sword") < Stats.skill(stats, id()) ->
        {:error, "你的基本剑法火候不够，无法领会更高深的段家剑法。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 45 / neili 36（须持剑，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 45, neili: 36}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{
      "jing" => Kantele.Combat.Skills.Performs.DuanjiaSword.Jing,
      "jue" => Kantele.Combat.Skills.Performs.DuanjiaSword.Jue
    }
  end
end
