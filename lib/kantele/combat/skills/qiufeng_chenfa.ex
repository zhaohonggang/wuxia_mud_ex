defmodule Kantele.Combat.Skills.QiufengChenfa do
  @moduledoc """
  秋风尘法（对照 `kungfu/skill/qiufeng-chenfa.c`）

  鞭法载体：`valid_enable("whip")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/qiufeng_chenfa/`。

  学习门槛 `valid_learn/2`（max_neili>=300 / force>=60 / whip>=self）与练招消耗
  `practice_cost`（qi 35 / neili 10）已按 LPC 迁移（2026-10-30）。须持拂尘检查由 practice 流程把关；招式表沿用基类占位 TODO。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "qiufeng-chenfa"

  @impl true
  def valid_enable(usage), do: usage in ["whip", "parry"]

  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 300 ->
        {:error, "你的内力不足，没有办法练秋风尘法, 多练些内力再来吧。\n"}

      Stats.skill(stats, "force") < 60 ->
        {:error, "你的内功火候太浅。\n"}

      Stats.skill(stats, "whip") < Stats.skill(stats, id()) ->
        {:error, "你的基本鞭法火候不足，难以领会更高深的秋风尘法。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili), do: max_neili
  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 35 / neili 10（须持拂尘，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 35, neili: 10}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"chan" => Kantele.Combat.Skills.Performs.QiufengChenfa.Chan}
  end
end
