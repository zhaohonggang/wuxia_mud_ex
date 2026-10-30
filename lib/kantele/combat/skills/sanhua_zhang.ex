defmodule Kantele.Combat.Skills.SanhuaZhang do
  @moduledoc """
  三花掌法（对照 `kungfu/skill/sanhua-zhang.c`）

  掌法载体：`valid_enable("strike")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/sanhua_zhang/`。

  学习门槛 `valid_learn/2`（force>=60 / max_neili>=300 / strike>=sanhua-zhang）与
  练招消耗 `practice_cost`（LPC 扣 qi 65 / neili 66，须空手）已按 LPC 迁移（2026-10-30）。
  LPC 的「须空手（weapon/secondary_weapon）」检查未在 `valid_learn` 建模
  （空手由 practice 流程把关），招式表沿用基类占位 TODO。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "sanhua-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["strike", "parry"]

  # LPC valid_learn 要求 force>=60 / max_neili>=300 / strike>=sanhua-zhang
  # （空手检查 weapon/secondary_weapon 沿用 practice 流程把关，未在此建模）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      Stats.skill(stats, "force") < 60 ->
        {:error, "你的内功火候不够，无法学散花掌。\n"}

      not is_nil(max_neili) and max_neili < 300 ->
        {:error, "你的内力太弱，无法练散花掌。\n"}

      Stats.skill(stats, "strike") < Stats.skill(stats, id()) ->
        {:error, "你的基本掌法火候水平有限，无法领会更高深的散花掌。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 65 / neili 66（须空手，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 65, neili: 66}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"san" => Kantele.Combat.Skills.Performs.SanhuaZhang.San}
  end
end
