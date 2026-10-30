defmodule Kantele.Combat.Skills.LongchengShendao do
  @moduledoc """
  龙城神刀（对照 `kungfu/skill/longcheng-shendao.c`）

  刀法载体：`valid_enable("blade")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/longcheng_shendao/`。

  学习门槛 `valid_learn/2`（max_neili>=1000 / force>=150 / blade>=80 / blade>=self）与练招消耗
  `practice_cost`（qi 65 / neili 68）已按 LPC 迁移（2026-10-30）。须持刀检查由 practice 流程把关；招式表沿用基类占位 TODO。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "longcheng-shendao"

  @impl true
  def valid_enable(usage), do: usage in ["blade", "parry"]

  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 1000 ->
        {:error, "你的内力不够。\n"}

      Stats.skill(stats, "force") < 150 ->
        {:error, "你的内功火候太浅。\n"}

      Stats.skill(stats, "blade") < 80 ->
        {:error, "你的基本刀法火候不够。\n"}

      Stats.skill(stats, "blade") < Stats.skill(stats, id()) ->
        {:error, "你的刀法水平有限，无法领会更高深的龙城神刀。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili), do: max_neili
  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 65 / neili 68（须持刀，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 65, neili: 68}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{
      "feng" => Kantele.Combat.Skills.Performs.LongchengShendao.Feng,
      "fengyu" => Kantele.Combat.Skills.Performs.LongchengShendao.Fengyu
    }
  end
end
