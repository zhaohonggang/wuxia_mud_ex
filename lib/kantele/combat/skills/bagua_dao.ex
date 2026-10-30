defmodule Kantele.Combat.Skills.BaguaDao do
  @moduledoc """
  八卦刀法（对照 `kungfu/skill/bagua-dao.c`）

  刀法载体：`valid_enable("blade")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/bagua_dao/`。

  学习门槛 `valid_learn/2`（max_neili>=1200 / force>=150 / blade>=100 / blade>=bagua-dao）与
  练招消耗 `practice_cost`（LPC 扣 qi 55 / neili 70，须持刀）已按 LPC 迁移（2026-10-30）。
  LPC 的须持刀（weapon skill_type=="blade"）检查由 practice 流程把关，未写入 `valid_learn`；招式表沿用基类占位 TODO。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "bagua-dao"

  @impl true
  def valid_enable(usage), do: usage in ["blade", "parry"]

  # LPC valid_learn 要求 max_neili>=1200 / force>=150 / blade>=100 / blade>=bagua-dao
  # （须持刀检查 weapon skill_type=="blade" 沿用 practice 流程把关，未在此建模）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 1200 ->
        {:error, "你的内力修为尚浅，无法练习八卦刀法。\n"}

      Stats.skill(stats, "force") < 150 ->
        {:error, "你的内功火候太浅。\n"}

      Stats.skill(stats, "blade") < 100 ->
        {:error, "你的基本刀法水平有限，无法练习八卦刀法。\n"}

      Stats.skill(stats, "blade") < Stats.skill(stats, id()) ->
        {:error, "你的基本刀法水平有限，无法领会更高深的八卦刀法。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 55 / neili 70（须持刀，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 55, neili: 70}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{
      "mang" => Kantele.Combat.Skills.Performs.BaguaDao.Mang,
      "sha" => Kantele.Combat.Skills.Performs.BaguaDao.Sha,
      "tian" => Kantele.Combat.Skills.Performs.BaguaDao.Tian
    }
  end
end
