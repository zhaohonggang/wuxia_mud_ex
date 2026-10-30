defmodule Kantele.Combat.Skills.PangenCuojiefu do
  @moduledoc """
  盘根错节斧（对照 `kungfu/skill/pangen-cuojiefu.c`）

  斧/锤法载体：`valid_enable("hammer")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/pangen_cuojiefu/`。

  学习门槛 `valid_learn/2`（force>=50 / max_neili>=600 / hammer>=30 / hammer>=self）与练招消耗
  `practice_cost`（qi 80 / neili 52）已按 LPC 迁移（2026-10-30）。须持锤检查由 practice 流程把关；招式表沿用基类占位 TODO。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "pangen-cuojiefu"

  @impl true
  def valid_enable(usage), do: usage in ["hammer", "parry"]

  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      Stats.skill(stats, "force") < 50 ->
        {:error, "你的内功火候不够，无法学盘根错节斧。\n"}

      not is_nil(max_neili) and max_neili < 600 ->
        {:error, "你的内力修为太弱，无法练盘根错节斧。\n"}

      Stats.skill(stats, "hammer") < 30 ->
        {:error, "你的基本锤法等级太低，无法学盘根错节斧。\n"}

      Stats.skill(stats, "hammer") < Stats.skill(stats, id()) ->
        {:error, "你的基本锤法水平有限，无法领会更高深的盘根错节斧。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili), do: max_neili
  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 80 / neili 52（须持锤，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 80, neili: 52}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"cuo" => Kantele.Combat.Skills.Performs.PangenCuojiefu.Cuo}
  end
end
