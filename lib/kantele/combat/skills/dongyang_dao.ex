defmodule Kantele.Combat.Skills.DongyangDao do
  @moduledoc """
  东洋刀法（对照 `kungfu/skill/dongyang-dao.c`）

  刀法载体：`valid_enable("blade")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/dongyang_dao/`。

  学习门槛 `valid_learn/2`（max_neili>=100 / force>=30 / blade>=dongyang-dao）与
  练招消耗 `practice_cost`（LPC 扣 qi 60 / neili 42，须持刀）已按 LPC 迁移（2026-10-30）。
  LPC 的「须持刀（weapon skill_type=="blade"）」检查未在 `valid_learn` 建模
  （由 practice 流程把关），招式表沿用基类占位 TODO。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "dongyang-dao"

  @impl true
  def valid_enable(usage), do: usage in ["blade", "parry"]

  # LPC valid_learn 要求 max_neili>=100 / force>=30 / blade>=dongyang-dao（LPC 有重复 blade<self 行，合并为一；须持刀检查由 practice 流程把关）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 100 ->
        {:error, "你的内力不够。\n"}

      Stats.skill(stats, "force") < 30 ->
        {:error, "你的内功火候不够。\n"}

      Stats.skill(stats, "blade") < Stats.skill(stats, id()) ->
        {:error, "你的基本刀法水平有限，无法领会更高深的东洋刀法。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 60 / neili 42（须持刀，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 60, neili: 42}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{
      "luan" => Kantele.Combat.Skills.Performs.DongyangDao.Luan,
      "zhan" => Kantele.Combat.Skills.Performs.DongyangDao.Zhan
    }
  end
end
