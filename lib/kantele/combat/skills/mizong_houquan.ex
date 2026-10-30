defmodule Kantele.Combat.Skills.MizongHouquan do
  @moduledoc """
  迷踪猴拳（对照 `kungfu/skill/mizong-houquan.c`）

  拳法载体：`valid_enable("cuff")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/mizong_houquan/`。

  学习门槛 `valid_learn/2`（max_neili>=1200 / force>=100 / cuff>=100 / cuff>=mizong-houquan）与
  练招消耗 `practice_cost`（LPC 扣 qi 55 / neili 78，须空手）已按 LPC 迁移（2026-10-30）。
  LPC 的「须空手（weapon/secondary_weapon 为空）」检查未在 `valid_learn` 建模
  （由 practice 流程把关），招式表沿用基类占位 TODO。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "mizong-houquan"

  @impl true
  def valid_enable(usage), do: usage in ["cuff", "parry"]

  # LPC valid_learn 要求 max_neili>=1200 / force>=100 / cuff>=100 / cuff>=mizong-houquan
  # （须空手检查 weapon/secondary_weapon 为空 沿用 practice 流程把关，未在此建模）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 1200 ->
        {:error, "你的内力修为太弱，无法练迷踪猴拳。\n"}

      Stats.skill(stats, "force") < 100 ->
        {:error, "你的基本内功火候不够，无法练迷踪猴拳。\n"}

      Stats.skill(stats, "cuff") < 100 ->
        {:error, "你的基本拳法火候不够，无法练迷踪猴拳。\n"}

      Stats.skill(stats, "cuff") < Stats.skill(stats, id()) ->
        {:error, "你的基本拳法水平有限，无法领会更高深的迷踪猴拳。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 55 / neili 78（须空手，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 55, neili: 78}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"zhou" => Kantele.Combat.Skills.Performs.MizongHouquan.Zhou}
  end
end
