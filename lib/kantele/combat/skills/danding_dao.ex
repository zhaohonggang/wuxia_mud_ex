defmodule Kantele.Combat.Skills.DandingDao do
  @moduledoc """
  澹定刀法（对照 `kungfu/skill/danding-dao.c`）

  刀法载体：`valid_enable("blade")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/danding_dao/`。

  学习门槛 `valid_learn/2`（max_neili>=200 / force>=50 / blade>=danding-dao）与
  练招消耗 `practice_cost`（LPC 扣 qi 45 / neili 43，须持刀）已按 LPC 迁移（2026-10-30）。
  LPC 的「须持刀（weapon skill_type=="blade"）」检查未在 `valid_learn` 建模
  （由 practice 流程把关），招式表沿用基类占位 TODO。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "danding-dao"

  @impl true
  def valid_enable(usage), do: usage in ["blade", "parry"]

  # LPC valid_learn 要求 max_neili>=200 / force>=50 / blade>=danding-dao（须持刀检查由 practice 流程把关）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 200 ->
        {:error, "你的内力修为不够。\n"}

      Stats.skill(stats, "force") < 50 ->
        {:error, "你的内功火候太浅。\n"}

      Stats.skill(stats, "blade") < Stats.skill(stats, id()) ->
        {:error, "你的基本刀法水平有限，无法领会更高深的丹碇刀法。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 45 / neili 43（须持刀，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 45, neili: 43}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"kou" => Kantele.Combat.Skills.Performs.DandingDao.Kou}
  end
end
