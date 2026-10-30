defmodule Kantele.Combat.Skills.LutouZhang do
  @moduledoc """
  鹿头杖法（对照 `kungfu/skill/lutou-zhang.c`）

  杖法载体：`valid_enable("staff")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/lutou_zhang/`。

  学习门槛 `valid_learn/2`（max_neili>=200 / force>=60 / staff>=20 / staff>=lutou-zhang）与
  练招消耗 `practice_cost`（LPC 扣 qi 75 / neili 78，须持杖）已按 LPC 迁移（2026-10-30）。
  LPC 的「须持杖（weapon skill_type=="staff"）」检查未在 `valid_learn` 建模
  （由 practice 流程把关），招式表沿用基类占位 TODO。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "lutou-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["staff", "parry"]

  # LPC valid_learn 要求 max_neili>=200 / force>=60 / staff>=20 / staff>=lutou-zhang（须持杖检查由 practice 流程把关）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 200 ->
        {:error, "你的内力修为不足，无法学习鹿头杖法。\n"}

      Stats.skill(stats, "force") < 60 ->
        {:error, "你的内功火候太浅，无法学习鹿头杖法。\n"}

      Stats.skill(stats, "staff") < 20 ->
        {:error, "你的基本杖法太浅，无法学习鹿头杖法。\n"}

      Stats.skill(stats, "staff") < Stats.skill(stats, id()) ->
        {:error, "你的基本杖法水平有限，无法领会更高深的鹿头杖法。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 75 / neili 78（须持杖，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 75, neili: 78}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"tong" => Kantele.Combat.Skills.Performs.LutouZhang.Tong}
  end
end
