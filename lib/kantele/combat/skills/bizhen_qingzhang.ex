defmodule Kantele.Combat.Skills.BizhenQingzhang do
  @moduledoc """
  裨阵清掌（对照 `kungfu/skill/bizhen-qingzhang.c`）

  掌法载体：`valid_enable("strike")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/bizhen_qingzhang/`。

  学习门槛 `valid_learn/2`（max_neili>=1000 / force>=200 / strike>=140 / strike>=bizhen-qingzhang）与
  练招消耗 `practice_cost`（LPC 扣 qi 80 / neili 80，空手）已按 LPC 迁移（2026-10-30）。
  LPC 的「空手（query_temp("weapon")）」检查未在 `valid_learn` 建模
  （学习/练习本就空手，由 practice 流程把关），招式表沿用基类占位 TODO。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "bizhen-qingzhang"

  @impl true
  def valid_enable(usage), do: usage in ["strike", "parry"]

  # LPC valid_learn 要求 max_neili>=1000 / force>=200 / strike>=140 / strike>=bizhen-qingzhang（空手检查由 practice 流程把关）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      Stats.skill(stats, "force") < 200 ->
        {:error, "你的内功火候不够，无法练习碧针清掌。\n"}

      not is_nil(max_neili) and max_neili < 1000 ->
        {:error, "你的内力太弱，无法练习碧针清掌。\n"}

      Stats.skill(stats, "strike") < 140 ->
        {:error, "你的基本掌法火候不够，无法练习碧针清掌。\n"}

      Stats.skill(stats, "strike") < Stats.skill(stats, id()) ->
        {:error, "你的基本掌法水平有限，无法领会更高深的碧针清掌。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 80 / neili 80（空手）"
  @impl true
  def practice_cost(), do: %{qi: 80, neili: 80}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"pengpai" => Kantele.Combat.Skills.Performs.BizhenQingzhang.Pengpai}
  end
end
