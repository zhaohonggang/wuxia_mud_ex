defmodule Kantele.Combat.Skills.RuanhongZhusuo do
  @moduledoc """
  软红爪锁（对照 `kungfu/skill/ruanhong-zhusuo.c`）

  鞭/爪法载体：`valid_enable("whip")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/ruanhong_zhusuo/`。

  学习门槛 `valid_learn/2`（max_neili>=1000 / force>=150 / whip>=100 / whip>=self）与练招消耗
  `practice_cost`（qi 75 / neili 85）已按 LPC 迁移（2026-10-30）。须持鞭检查由 practice 流程把关；招式表沿用基类占位 TODO。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "ruanhong-zhusuo"

  @impl true
  def valid_enable(usage), do: usage in ["whip", "parry"]

  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 1000 ->
        {:error, "你的内力不足，没有办法练软红蛛索，多练些内力再来吧。\n"}

      Stats.skill(stats, "force") < 150 ->
        {:error, "你的内功火候太浅，没有办法练软红蛛索。\n"}

      Stats.skill(stats, "whip") < 100 ->
        {:error, "你的基本鞭法火候太浅，没有办法练软红蛛索。\n"}

      Stats.skill(stats, "whip") < Stats.skill(stats, id()) ->
        {:error, "你的基本鞭法水平还不够，无法领会更高深的软红蛛索。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili), do: max_neili
  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 75 / neili 85（须持鞭，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 75, neili: 85}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{
      "bohu" => Kantele.Combat.Skills.Performs.RuanhongZhusuo.Bohu,
      "pan" => Kantele.Combat.Skills.Performs.RuanhongZhusuo.Pan,
      "suo" => Kantele.Combat.Skills.Performs.RuanhongZhusuo.Suo,
      "teng" => Kantele.Combat.Skills.Performs.RuanhongZhusuo.Teng
    }
  end
end
