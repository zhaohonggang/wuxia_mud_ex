defmodule Kantele.Combat.Skills.HexingBifa do
  @moduledoc """
  鹤形笔法（对照 `kungfu/skill/hexing-bifa.c`）

  笔/匕首法载体：`valid_enable("dagger")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/hexing_bifa/`。

  学习门槛 `valid_learn/2`（max_neili>=300 / dagger>=hexing-bifa）与
  练招消耗 `practice_cost`（LPC 扣 qi 55 / neili 52，须持短兵）已按 LPC 迁移（2026-10-30）。
  LPC 的「须持短兵（weapon skill_type=="dagger"）」检查未在 `valid_learn` 建模
  （由 practice 流程把关），招式表沿用基类占位 TODO。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "hexing-bifa"

  @impl true
  def valid_enable(usage), do: usage in ["dagger", "parry"]

  # LPC valid_learn 要求 max_neili>=300 / dagger>=hexing-bifa（须持短兵检查由 practice 流程把关）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 300 ->
        {:error, "你的内力修为不够。\n"}

      Stats.skill(stats, "dagger") < Stats.skill(stats, id()) ->
        {:error, "你的基本短兵水平有限，无法领会更高深的鹤形笔法。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 55 / neili 52（须持短兵，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 55, neili: 52}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"dian" => Kantele.Combat.Skills.Performs.HexingBifa.Dian}
  end
end
