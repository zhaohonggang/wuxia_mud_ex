defmodule Kantele.Combat.Skills.PoguangDao do
  @moduledoc """
  破光刀法（对照 `kungfu/skill/poguang-dao.c`）

  刀法载体：`valid_enable("blade")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/poguang_dao/`。

  学习门槛 `valid_learn/2`（max_neili>=800 / force>=120 / blade>=100 / blade>=poguang-dao）与
  练招消耗 `practice_cost`（LPC 扣 qi 40 / neili 50）已按 LPC 迁移（2026-10-30）。
  LPC 原文不一致：`valid_learn` 要求持刀（blade），而 `practice_skill` 检查 sword；武器检查照前批由 practice 流程把关，未写入 `valid_learn`；招式表沿用基类占位 TODO。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "poguang-dao"

  @impl true
  def valid_enable(usage), do: usage in ["blade", "parry"]

  # LPC valid_learn 要求 max_neili>=800 / force>=120 / blade>=100 / blade>=poguang-dao
  # （valid_learn 原文检查持刀 blade；practice_skill 写 sword，两处不一致，均照前批由 practice 流程把关）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 800 ->
        {:error, "你的内力修为不够，无法学习破光刀法。\n"}

      Stats.skill(stats, "force") < 120 ->
        {:error, "你的内功火候太浅，无法学习破光刀法。\n"}

      Stats.skill(stats, "blade") < 100 ->
        {:error, "你的基本刀法火候不够，无法学习破光刀法。\n"}

      Stats.skill(stats, "blade") < Stats.skill(stats, id()) ->
        {:error, "你的基本剑法火候有限，无法领会更高深的破光刀法。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 40 / neili 50（须持武器，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 40, neili: 50}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{
      "bing" => Kantele.Combat.Skills.Performs.PoguangDao.Bing,
      "yang" => Kantele.Combat.Skills.Performs.PoguangDao.Yang
    }
  end
end
