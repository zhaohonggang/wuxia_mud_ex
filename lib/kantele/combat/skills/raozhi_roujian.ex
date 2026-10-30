defmodule Kantele.Combat.Skills.RaozhiRoujian do
  @moduledoc """
  柔指柔剑（对照 `kungfu/skill/raozhi-roujian.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/raozhi_roujian/`。

  学习门槛 `valid_learn/2`（max_neili>=100 / force>=20 / sword>=self）与练招消耗
  `practice_cost`（qi 35 / neili 30）已按 LPC 迁移（2026-10-30）。须持剑检查由 practice 流程把关；招式表沿用基类占位 TODO。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "raozhi-roujian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "parry"]

  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 100 ->
        {:error, "你的内力不够。\n"}

      Stats.skill(stats, "force") < 20 ->
        {:error, "你的内功火候太浅。\n"}

      Stats.skill(stats, "sword") < Stats.skill(stats, id()) ->
        {:error, "你的基本剑法水平有限，无法领会更高深的绕指柔剑。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili), do: max_neili
  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 35 / neili 30（须持剑，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 35, neili: 30}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"chuan" => Kantele.Combat.Skills.Performs.RaozhiRoujian.Chuan}
  end
end
