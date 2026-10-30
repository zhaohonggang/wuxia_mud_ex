defmodule Kantele.Combat.Skills.LingsheZhangfa do
  @moduledoc """
  灵蛇杖法（对照 `kungfu/skill/lingshe-zhangfa.c`）

  杖法载体：`valid_enable("staff")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/lingshe_zhangfa/`。

  学习门槛 `valid_learn/2`（max_neili>=1000 / force>=150 / staff>=100 / staff>=self）与练招消耗
  `practice_cost`（qi 60 / neili 69）已按 LPC 迁移（2026-10-30）。须持杖检查由 practice 流程把关；招式表沿用基类占位 TODO。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "lingshe-zhangfa"

  @impl true
  def valid_enable(usage), do: usage in ["staff", "parry"]

  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 1000 ->
        {:error, "你的内力不够。\n"}

      Stats.skill(stats, "force") < 150 ->
        {:error, "你的内功火候不够。\n"}

      Stats.skill(stats, "staff") < 100 ->
        {:error, "你的基本杖法还不到家，不能学习灵蛇杖法。\n"}

      Stats.skill(stats, "staff") < Stats.skill(stats, id()) ->
        {:error, "你的基本杖法水平不够，无法领会更高深的灵蛇杖法。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili), do: max_neili
  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 60 / neili 69（须持杖，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 60, neili: 69}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{
      "chan" => Kantele.Combat.Skills.Performs.LingsheZhangfa.Chan,
      "qianshe" => Kantele.Combat.Skills.Performs.LingsheZhangfa.Qianshe,
      "wanshi" => Kantele.Combat.Skills.Performs.LingsheZhangfa.Wanshi,
      "wuji" => Kantele.Combat.Skills.Performs.LingsheZhangfa.Wuji
    }
  end
end
