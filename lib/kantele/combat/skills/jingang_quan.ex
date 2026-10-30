defmodule Kantele.Combat.Skills.JingangQuan do
  @moduledoc """
  金刚拳（对照 `kungfu/skill/jingang-quan.c`）

  拳法载体：`valid_enable("cuff")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/jingang_quan/`。

  学习门槛 `valid_learn/2`（force>=30 / max_neili>=100 / cuff>=jingang-quan）与
  练招消耗 `practice_cost`（LPC 扣 qi 59 / neili 58，须空手）已按 LPC 迁移（2026-10-30）。
  LPC 的「须空手（weapon/secondary_weapon）」检查与「cuff/level 低于招式解锁等级」的
  招式表门槛未在 `valid_learn` 建模（空手由 practice 流程把关，招式表沿用基类占位 TODO）。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "jingang-quan"

  @impl true
  def valid_enable(usage), do: usage in ["cuff", "parry"]

  # LPC valid_learn 要求 force>=30 / max_neili>=100 / cuff>=jingang-quan
  # （空手检查 weapon/secondary_weapon 沿用 practice 流程把关，未在此建模）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      Stats.skill(stats, "force") < 30 ->
        {:error, "你的内功火候不够，无法学大金刚拳。\n"}

      not is_nil(max_neili) and max_neili < 100 ->
        {:error, "你的内力太弱，无法练大金刚拳。\n"}

      Stats.skill(stats, "cuff") < Stats.skill(stats, id()) ->
        {:error, "你的基本拳法水平有限，无法领会更高深的大金刚拳。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 59 / neili 58（须空手，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 59, neili: 58}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"jingang" => Kantele.Combat.Skills.Performs.JingangQuan.Jingang}
  end
end
