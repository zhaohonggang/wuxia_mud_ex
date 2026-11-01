defmodule Kantele.Combat.Skills.CaiyanGong do
  @moduledoc """
  彩云功（对照 `kungfu/skill/caiyan-gong.c`）

  棍/杖法载体：`valid_enable("club")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/caiyan_gong/`。

  学习门槛 `valid_learn/2`（max_neili>=250 / force>=50 / dodge>=caiyan-gong / club>=caiyan-gong）与
  练招消耗 `practice_cost`（LPC 扣 qi 62 / neili 61，须持棍）已按 LPC 迁移（2026-10-30）。
  LPC 的「须持棍（weapon skill_type=="club"）」检查未在 `valid_learn` 建模
  （由 practice 流程把关），招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N一招「乳燕归巢」，手中$w如蜻蜓点水般，招招向$n的$l点去",
      "force" => 120,
      "attack" => 25,
      "dodge" => 75,
      "parry" => 82,
      "damage" => 10,
      "lvl" => 0,
      "skill_name" => "乳燕归巢"
    },
    %{
      "action" => "$N把$w平提胸口，一拧身，一招「蜻蜓点水」，$w猛地撩向$n的$l",
      "force" => 150,
      "attack" => 37,
      "dodge" => 73,
      "parry" => 81,
      "damage" => 15,
      "lvl" => 40,
      "skill_name" => "蜻蜓点水"
    },
    %{
      "action" => "$N一招「雪燕南归」，全身滴溜溜地在地上打个大转，$w向$n的$l间戳去",
      "force" => 180,
      "attack" => 42,
      "dodge" => 65,
      "parry" => 87,
      "damage" => 20,
      "lvl" => 80,
      "skill_name" => "雪燕南归"
    },
    %{
      "action" => "$N伏地一个滚翻，一招「平步青云」，$w挟呼呼风声迅猛扫向$n的足胫",
      "force" => 210,
      "attack" => 43,
      "dodge" => 68,
      "parry" => 85,
      "damage" => 25,
      "lvl" => 100,
      "skill_name" => "平步青云"
    },
    %{
      "action" => "$N一招「燕落长空」，身棍合一，棍端逼成一条直线，流星般向顶向$n的$l",
      "force" => 240,
      "attack" => 49,
      "dodge" => 73,
      "parry" => 91,
      "damage" => 30,
      "lvl" => 120,
      "skill_name" => "燕落长空"
    }
  ]

  @impl true
  def id(), do: "caiyan-gong"

  @impl true
  def valid_enable(usage), do: usage in ["club", "parry"]

  # LPC valid_learn 要求 max_neili>=250 / force>=50 / dodge>=self / club>=self（须持棍检查由 practice 流程把关）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 250 ->
        {:error, "你的内力不够。\n"}

      Stats.skill(stats, "force") < 50 ->
        {:error, "你的内功火候太浅。\n"}

      Stats.skill(stats, "dodge") < Stats.skill(stats, id()) ->
        {:error, "你的基本轻功水平有限，无法领会更高深的采燕功。\n"}

      Stats.skill(stats, "club") < Stats.skill(stats, id()) ->
        {:error, "你的基本棍法水平有限，无法领会更高深的采燕功。\n"}

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
  def query_action(level, rng \\ &:rand.uniform/1) do
    Skill.pick_action(@actions, level, rng)
  end

  @impl true
  def query_action(level, rng, _attacker), do: query_action(level, rng)

  @impl true
  def perform_list() do
    %{"huan" => Kantele.Combat.Skills.Performs.CaiyanGong.Huan}
  end
  def actions(), do: @actions

end
