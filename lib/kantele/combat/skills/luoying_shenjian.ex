defmodule Kantele.Combat.Skills.LuoyingShenjian do
  @moduledoc """
  落英神剑（对照 `kungfu/skill/luoying-shenjian.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/luoying_shenjian/`。

  学习门槛 `valid_learn/2`（force>=30 / max_neili>=250 / sword>=luoying-shenjian）与
  练招消耗 `practice_cost`（LPC 扣 qi 45 / neili 41，须持剑）已按 LPC 迁移（2026-10-30）。
  LPC 的须持剑（weapon skill_type=="sword"，valid_learn 与 practice_skill 均检查）由 practice 流程把关，未写入 `valid_learn`；招式表沿用基类占位 TODO。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "luoying-shenjian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "parry"]

  # LPC valid_learn 要求 force>=30 / max_neili>=250 / sword>=luoying-shenjian
  # （须持剑检查 weapon skill_type=="sword" 沿用 practice 流程把关，未在此建模）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      Stats.skill(stats, "force") < 30 ->
        {:error, "你的内功火候不够，不能练落英神剑。\n"}

      not is_nil(max_neili) and max_neili < 250 ->
        {:error, "你的内力修为不够，不能练落英神剑。\n"}

      Stats.skill(stats, "sword") < Stats.skill(stats, id()) ->
        {:error, "你的基本剑法水平有限，无法领会更高深的落英神剑。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 45 / neili 41（须持剑，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 45, neili: 41}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"sui" => Kantele.Combat.Skills.Performs.LuoyingShenjian.Sui}
  end
end
