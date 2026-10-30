defmodule Kantele.Combat.Skills.KuimangDao do
  @moduledoc """
  蝰蟒刀法（对照 `kungfu/skill/kuimang-dao.c`）

  刀法载体：`valid_enable("blade")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/kuimang_dao/`。

  学习门槛 `valid_learn/2`（max_neili>=50 / force>=10 / blade>=kuimang-dao）与
  练招消耗 `practice_cost`（LPC 扣 qi 45 / neili 43，须持刀）已按 LPC 迁移（2026-10-30）。
  LPC 的须持刀（weapon skill_type=="blade"）检查由 practice 流程把关，未写入 `valid_learn`；招式表沿用基类占位 TODO。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "kuimang-dao"

  @impl true
  def valid_enable(usage), do: usage in ["blade", "parry"]

  # LPC valid_learn 要求 max_neili>=50 / force>=10 / blade>=kuimang-dao
  # （须持刀检查 weapon skill_type=="blade" 沿用 practice 流程把关，未在此建模）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 50 ->
        {:error, "你的内力修为不够。\n"}

      Stats.skill(stats, "force") < 10 ->
        {:error, "你的内功火候太浅。\n"}

      Stats.skill(stats, "blade") < Stats.skill(stats, id()) ->
        {:error, "你的基本刀法水平有限，无法领会更高深的蝰蟒刀法。\n"}

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
    %{"pan" => Kantele.Combat.Skills.Performs.KuimangDao.Pan}
  end
end
