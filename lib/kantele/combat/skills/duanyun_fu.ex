defmodule Kantele.Combat.Skills.DuanyunFu do
  @moduledoc """
  断云拂法（对照 `kungfu/skill/duanyun-fu.c`）

  斧法载体：`valid_enable("axe")` / `valid_enable("parry")`（LPC `usage=="axe" || usage=="parry"`；
  旧版本误作 `club`，已按 LPC 修正）。

  绝招实现见 `lib/kantele/combat/skills/performs/duanyun_fu/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn`（force>=20 / max_neili>=150）已按 LPC 迁移。
  - LPC `practice_skill` 的「须持斧（`skill_type=="axe"`）」检查由 practice 流程把关，未写入
    `valid_learn`；扣 `qi` 80、`receive_damage("neili", -12)`（**负伤害 = 回 12 点内力**，
    LPC 原样 bug），`practice_cost` 只能表达非负消耗，故 neili 记 0（实际效果是回内）。
  - 招式表未建模（绝招见 `performs/duanyun_fu/`）。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "duanyun-fu"

  @impl true
  def valid_enable(usage), do: usage in ["axe", "parry"]

  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      Stats.skill(stats, "force") < 20 ->
        {:error, "你的内功心法火候不够，无法学断云斧。\n"}

      not is_nil(max_neili) and max_neili < 150 ->
        {:error, "你的内力太弱，无法练断云斧。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "LPC practice_skill 扣 qi 80（neili 侧原样为回内，记 0）"
  @impl true
  def practice_cost(), do: %{qi: 80, neili: 0}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"tiaoyan" => Kantele.Combat.Skills.Performs.DuanyunFu.Tiaoyan}
  end
end
