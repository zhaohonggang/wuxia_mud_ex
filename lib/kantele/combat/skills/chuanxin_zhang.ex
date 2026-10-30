defmodule Kantele.Combat.Skills.ChuanxinZhang do
  @moduledoc """
  穿心掌法（对照 `kungfu/skill/chuanxin-zhang.c`）

  掌法载体：`valid_enable("strike")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/chuanxin_zhang/`。

  学习门槛 `valid_learn/2`（max_neili>=200 / strike>=30 / strike>=chuanxin-zhang）与
  练招消耗 `practice_cost`（LPC 扣 qi 45 / neili 48，空手）已按 LPC 迁移（2026-10-30）。
  LPC 的「空手（query_temp("weapon")）」检查未在 `valid_learn` 建模
  （学习/练习本就空手，由 practice 流程把关），招式表沿用基类占位 TODO。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "chuanxin-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["strike", "parry"]

  # LPC valid_learn 要求 max_neili>=200 / strike>=30 / strike>=chuanxin-zhang（空手检查由 practice 流程把关）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 200 ->
        {:error, "你的内力修为太浅，无法练习穿心掌。\n"}

      Stats.skill(stats, "strike") < 30 ->
        {:error, "你的基本掌法太差，无法领会穿心掌。\n"}

      Stats.skill(stats, "strike") < Stats.skill(stats, id()) ->
        {:error, "你的基本掌法火候不够，无法领会更高深的穿心掌。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 45 / neili 48（空手）"
  @impl true
  def practice_cost(), do: %{qi: 45, neili: 48}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"zhui" => Kantele.Combat.Skills.Performs.ChuanxinZhang.Zhui}
  end
end
