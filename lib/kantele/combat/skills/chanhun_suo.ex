defmodule Kantele.Combat.Skills.ChanhunSuo do
  @moduledoc """
  缠魂锁法（对照 `kungfu/skill/chanhun-suo.c`）

  鞭/锁法载体：`valid_enable("whip")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/chanhun_suo/`。

  学习门槛 `valid_learn/2`（max_neili>=400 / force>=80 / whip>=60 / whip>=chanhun-suo）与
  练招消耗 `practice_cost`（LPC 扣 qi 50 / neili 50，须持鞭）已按 LPC 迁移（2026-10-30）。
  LPC 的「须持鞭（weapon skill_type=="whip"）」检查未在 `valid_learn` 建模
  （由 practice 流程把关），招式表沿用基类占位 TODO。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "chanhun-suo"

  @impl true
  def valid_enable(usage), do: usage in ["whip", "parry"]

  # LPC valid_learn 要求 max_neili>=400 / force>=80 / whip>=60 / whip>=chanhun-suo（须持鞭检查由 practice 流程把关）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 400 ->
        {:error, "你的内力不足，没有办法练习缠魂索。\n"}

      Stats.skill(stats, "force") < 80 ->
        {:error, "你的内功火候太浅。\n"}

      Stats.skill(stats, "whip") < 60 ->
        {:error, "你的基本鞭法火候太浅。\n"}

      Stats.skill(stats, "whip") < Stats.skill(stats, id()) ->
        {:error, "你的基本鞭法水平有限，无法领会更高深的缠魂索。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 50 / neili 50（须持鞭，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 50, neili: 50}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{
      "duo" => Kantele.Combat.Skills.Performs.ChanhunSuo.Duo,
      "suo" => Kantele.Combat.Skills.Performs.ChanhunSuo.Suo
    }
  end
end
