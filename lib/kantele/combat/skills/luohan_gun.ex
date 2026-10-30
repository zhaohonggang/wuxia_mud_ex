defmodule Kantele.Combat.Skills.LuohanGun do
  @moduledoc """
  罗汉棍法（对照 `kungfu/skill/luohan-gun.c`）

  棍法载体：`valid_enable("club")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/luohan_gun/`。

  学习门槛 `valid_learn/2`（max_neili>=1200 / force>=100 / club>=100 /
  club>=luohan-gun）与练招消耗 `practice_cost`（LPC 扣 qi 62 / neili 61，须持棍）
  已按 LPC 迁移（2026-10-30）。LPC 的「须持棍（weapon skill_type=="club"）」检查
  未在 `valid_learn` 建模（由 practice 流程把关），招式表沿用基类占位 TODO。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "luohan-gun"

  @impl true
  def valid_enable(usage), do: usage in ["club", "parry"]

  # LPC valid_learn 要求 max_neili>=1200 / force>=100 / club>=100 / club>=luohan-gun
  # （须持棍检查 weapon skill_type=="club" 沿用 practice 流程把关，未在此建模）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 1200 ->
        {:error, "你的内力不够。\n"}

      Stats.skill(stats, "force") < 100 ->
        {:error, "你的内功火候太浅。\n"}

      Stats.skill(stats, "club") < 100 ->
        {:error, "你的基本棍法水平还不足以学习十八罗汉棍法。\n"}

      Stats.skill(stats, "club") < Stats.skill(stats, id()) ->
        {:error, "你的基本棍法水平有限，无法领会更高深的十八罗汉棍法。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 62 / neili 61（须持棍，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 62, neili: 61}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{
      "shibaluohan" => Kantele.Combat.Skills.Performs.LuohanGun.Shibaluohan,
      "xiangmo" => Kantele.Combat.Skills.Performs.LuohanGun.Xiangmo
    }
  end
end
