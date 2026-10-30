defmodule Kantele.Combat.Skills.CanghongBifa do
  @moduledoc """
  沧虹笔法（对照 `kungfu/skill/canghong-bifa.c`）

  笔/匕首法载体：`valid_enable("dagger")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/canghong_bifa/`。

  学习门槛 `valid_learn/2`（max_neili>=500 / force>=100 / dagger>=30 / dagger>=canghong-bifa）与
  练招消耗 `practice_cost`（LPC 扣 qi 65 / neili 62，须持短兵）已按 LPC 迁移（2026-10-30）。
  LPC 的「须持短兵（weapon skill_type=="dagger"）」检查未在 `valid_learn` 建模
  （由 practice 流程把关），招式表沿用基类占位 TODO。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "canghong-bifa"

  @impl true
  def valid_enable(usage), do: usage in ["dagger", "parry"]

  # LPC valid_learn 要求 max_neili>=500 / force>=100 / dagger>=30 / dagger>=self（须持短兵检查由 practice 流程把关）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 500 ->
        {:error, "你的内力不够。\n"}

      Stats.skill(stats, "force") < 100 ->
        {:error, "你的内功火候太浅。\n"}

      Stats.skill(stats, "dagger") < 30 ->
        {:error, "你的基本短兵火候太浅。\n"}

      Stats.skill(stats, "dagger") < Stats.skill(stats, id()) ->
        {:error, "你的基本短兵水平有限，无法领会更高深的苍虹笔法。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 65 / neili 62（须持短兵，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 65, neili: 62}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"jing" => Kantele.Combat.Skills.Performs.CanghongBifa.Jing}
  end
end
