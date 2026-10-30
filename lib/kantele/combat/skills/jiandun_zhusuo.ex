defmodule Kantele.Combat.Skills.JiandunZhusuo do
  @moduledoc """
  剑盾爪锁（对照 `kungfu/skill/jiandun-zhusuo.c`）

  鞭/爪法载体：`valid_enable("whip")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/jiandun_zhusuo/`。

  学习门槛 `valid_learn/2`（max_neili>=500 / force>=100 / whip>=20 / whip>=self）与练招消耗
  `practice_cost`（qi 45 / neili 55）已按 LPC 迁移（2026-10-30）。须持鞭检查由 practice 流程把关；招式表沿用基类占位 TODO。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "jiandun-zhusuo"

  @impl true
  def valid_enable(usage), do: usage in ["whip", "parry"]

  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 500 ->
        {:error, "你的内力不足，没有办法练剑盾珠索。\n"}

      Stats.skill(stats, "force") < 100 ->
        {:error, "你的内功火候太浅，没有办法练剑盾珠索。\n"}

      Stats.skill(stats, "whip") < 20 ->
        {:error, "你的基本鞭法火候太浅，没有办法练剑盾珠索。\n"}

      Stats.skill(stats, "whip") < Stats.skill(stats, id()) ->
        {:error, "你的基本鞭法水平还不够，无法领会更高深的剑盾珠索。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili), do: max_neili
  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 45 / neili 55（须持鞭，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 45, neili: 55}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{
      "fu" => Kantele.Combat.Skills.Performs.JiandunZhusuo.Fu,
      "qian" => Kantele.Combat.Skills.Performs.JiandunZhusuo.Qian
    }
  end
end
