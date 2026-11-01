defmodule Kantele.Combat.Skills.HanmeiJian do
  @moduledoc """
  寒梅剑法（对照 `kungfu/skill/hanmei-jian.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/hanmei_jian/`。

  学习门槛 `valid_learn/2`（max_neili>=200 / sword>=10 / sword>=hanmei-jian）与
  练招消耗 `practice_cost`（LPC 扣 qi 60 / neili 16，须持剑）已按 LPC 迁移（2026-10-30）。
  LPC 的「须持剑（weapon skill_type=="sword"）」检查未在 `valid_learn` 建模
  （由 practice 流程把关），招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N纵身跃起手中$w轻挥，一招「踏雪寻梅」，斩向$n后颈",
      "force" => 80,
      "attack" => 35,
      "dodge" => 30,
      "parry" => 10,
      "damage" => 7,
      "lvl" => 0,
      "skill_name" => "踏雪寻梅"
    },
    %{
      "action" => "$N手中$w连话三个弧形，一招「梅雪争春」，向$n的右臂齐肩斩落",
      "force" => 100,
      "attack" => 45,
      "dodge" => 45,
      "parry" => 22,
      "damage" => 11,
      "lvl" => 30,
      "skill_name" => "梅雪争春"
    },
    %{
      "action" => "$N轻吁一声，飞身一跃而起，一招「剑毒梅香」，连续向$n刺出数剑",
      "force" => 120,
      "attack" => 51,
      "dodge" => 53,
      "parry" => 18,
      "damage" => 15,
      "lvl" => 60,
      "skill_name" => "剑毒梅香"
    },
    %{
      "action" => "$N仰天一声清啸，斜行向前，一招「梅花三弄」，$w横削直击，击向$n的$l",
      "force" => 150,
      "attack" => 58,
      "dodge" => 52,
      "parry" => 20,
      "damage" => 20,
      "lvl" => 90,
      "skill_name" => "梅花三弄"
    }
  ]

  @impl true
  def id(), do: "hanmei-jian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "parry"]

  # LPC valid_learn 要求 max_neili>=200 / sword>=10 / sword>=hanmei-jian
  # （须持剑检查 weapon skill_type=="sword" 沿用 practice 流程把关，未在此建模）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 200 ->
        {:error, "你的内力不够，无法修习寒梅剑法。\n"}

      Stats.skill(stats, "sword") < 10 ->
        {:error, "你的基本剑法火候太浅，无法修习寒梅剑法。\n"}

      Stats.skill(stats, "sword") < Stats.skill(stats, id()) ->
        {:error, "你的基本剑法水平有限，无法领会更高深的寒梅剑法。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 60 / neili 16（须持剑，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 60, neili: 16}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Skill.pick_action(@actions, level, rng)
  end

  @impl true
  def query_action(level, rng, _attacker), do: query_action(level, rng)

  @impl true
  def perform_list() do
    %{"leng" => Kantele.Combat.Skills.Performs.HanmeiJian.Leng}
  end
  def actions(), do: @actions

end
