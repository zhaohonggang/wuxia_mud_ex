defmodule Kantele.Combat.Skills.HanxingBada do
  @moduledoc """
  寒星八打（对照 `kungfu/skill/hanxing-bada.c`）

  暗器/打法载体：`valid_enable("throwing")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/hanxing_bada/`。

  学习门槛 `valid_learn/2`（max_neili>=200 / throwing>=hanxing-bada）与
  练招消耗 `practice_cost`（LPC 扣 qi 40 / neili 45，须持暗器）已按 LPC 迁移（2026-10-30）。
  LPC 的「须持暗器（weapon skill_type=="throwing"）」检查未在 `valid_learn` 建模
  （由 practice 流程把关），招式表沿用基类占位 TODO。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "hanxing-bada"

  @impl true
  def valid_enable(usage), do: usage in ["throwing", "parry"]

  # LPC valid_learn 要求 max_neili>=200 / throwing>=hanxing-bada（须持暗器检查由 practice 流程把关）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 200 ->
        {:error, "你的内力不够，没有办法练寒星八打。\n"}

      Stats.skill(stats, "throwing") < Stats.skill(stats, id()) ->
        {:error, "你的基本暗器水平有限，无法领悟更高深的寒星八打术。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 40 / neili 45（须持暗器，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 40, neili: 45}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"lastrisk" => Kantele.Combat.Skills.Performs.HanxingBada.Lastrisk}
  end
end
