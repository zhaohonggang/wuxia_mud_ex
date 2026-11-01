defmodule Kantele.Combat.Skills.ShangjiaDao do
  @moduledoc """
  尚家刀法（对照 `kungfu/skill/shangjia-dao.c`）

  刀法载体：`valid_enable("blade")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/shangjia_dao/`。

  学习门槛 `valid_learn/2`（max_neili>=350 / force>=50 / blade>=shangjia-dao）与
  练招消耗 `practice_cost`（LPC 扣 qi 50 / neili 35，须持刀）已按 LPC 迁移（2026-10-30）。
  LPC 的须持刀（weapon skill_type=="blade"）检查由 practice 流程把关，未写入 `valid_learn`；招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N脚踏八卦方位，手中$w横推，由上至下向$n砍去",
      "force" => 145,
      "attack" => 35,
      "dodge" => 30,
      "parry" => 12,
      "damage" => 12,
      "lvl" => 0
    },
    %{
      "action" => "$N刀锋自下而上划了个半弧，$w一提一收，平刃挥向$n的颈部",
      "force" => 153,
      "attack" => 42,
      "dodge" => 40,
      "parry" => 15,
      "damage" => 18,
      "lvl" => 20
    },
    %{
      "action" => "$N脚踏八卦方位，斜步上前，将$w舞得如白雾一般压向$n",
      "force" => 168,
      "attack" => 51,
      "dodge" => 45,
      "parry" => 17,
      "damage" => 24,
      "lvl" => 40
    },
    %{
      "action" => "$N转“嵌”位至“易”位，$w缓缓的斜着向$n推去",
      "force" => 187,
      "attack" => 55,
      "dodge" => 55,
      "parry" => 21,
      "damage" => 35,
      "lvl" => 60
    },
    %{
      "action" => "$N手拖$w，转身跃起，一道白光射向$n的胸口",
      "force" => 201,
      "attack" => 55,
      "dodge" => 27,
      "parry" => 32,
      "damage" => 35,
      "lvl" => 80
    },
    %{
      "action" => "$N挥舞$w，上劈下撩，左挡右开，齐齐罩向$n",
      "force" => 227,
      "attack" => 70,
      "dodge" => 30,
      "parry" => 35,
      "damage" => 40,
      "lvl" => 100
    },
    %{
      "action" => "$N左脚跃步落地，$w顺势往前，挟风声劈向$n的$l",
      "force" => 260,
      "attack" => 80,
      "dodge" => 45,
      "parry" => 35,
      "damage" => 46,
      "lvl" => 120
    }
  ]

  @impl true
  def id(), do: "shangjia-dao"

  @impl true
  def valid_enable(usage), do: usage in ["blade", "parry"]

  # LPC valid_learn 要求 max_neili>=350 / force>=50 / blade>=shangjia-dao（无绝对刀法下限）
  # （须持刀检查 weapon skill_type=="blade" 沿用 practice 流程把关，未在此建模）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 350 ->
        {:error, "你的内力不够。\n"}

      Stats.skill(stats, "force") < 50 ->
        {:error, "你的基本内功火候太浅。\n"}

      Stats.skill(stats, "blade") < Stats.skill(stats, id()) ->
        {:error, "你的基本刀法火候有限，无法领会更高深的商家刀法。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 50 / neili 35（须持刀，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 50, neili: 35}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Skill.pick_action(@actions, level, rng)
  end

  @impl true
  def query_action(level, rng, _attacker), do: query_action(level, rng)

  @impl true
  def perform_list() do
    %{"juan" => Kantele.Combat.Skills.Performs.ShangjiaDao.Juan}
  end
  def actions(), do: @actions

end
