defmodule Kantele.Combat.Skills.BaishengDaofa do
  @moduledoc """
  百胜刀法（对照 `kungfu/skill/baisheng-daofa.c`）

  刀法载体：`valid_enable("blade")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/baisheng_daofa/`。

  学习门槛 `valid_learn/2`（max_neili>=600 / force>=100 / blade>=60 / blade>=baisheng-daofa）与
  练招消耗 `practice_cost`（LPC 扣 qi 45 / neili 68，须持刀）已按 LPC 迁移（2026-10-30）。
  LPC 的「须持刀（weapon skill_type=="blade"）」检查未在 `valid_learn` 建模
  （由 practice 流程把关），招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N手持$w一刀劈下，迅即无比，势不可当",
      "force" => 210,
      "dodge" => 20,
      "parry" => 25,
      "damage" => 44,
      "lvl" => 0
    },
    %{
      "action" => "$N刀锋自下而上划了个半弧，$w忽深忽吐，刺向$n的颈部",
      "force" => 250,
      "dodge" => 30,
      "parry" => 40,
      "damage" => 51,
      "lvl" => 25
    },
    %{
      "action" => "$N忽然将$w舞得天花乱坠，闪电般压向$n",
      "force" => 270,
      "dodge" => 35,
      "parry" => 50,
      "damage" => 56,
      "lvl" => 50
    },
    %{
      "action" => "$N一横$w，刀锋像门板一样向$n推去，封住$n所有的退路",
      "force" => 280,
      "dodge" => 45,
      "parry" => 55,
      "damage" => 62,
      "lvl" => 70
    },
    %{
      "action" => "$N转身跃起，手舞$w，身与刀进合做一道电光射向$n",
      "force" => 305,
      "dodge" => 50,
      "parry" => 75,
      "damage" => 70,
      "lvl" => 90
    },
    %{
      "action" => "$N挥舞$w，乱砍乱杀，$w化作道道白光，上下翻飞罩向$n",
      "force" => 330,
      "dodge" => 55,
      "parry" => 85,
      "damage" => 75,
      "lvl" => 110
    },
    %{
      "action" => "$N将$w使得毫无章法，不守半点规矩，偏生快得出奇，$w挟风声劈向$n的$l",
      "force" => 350,
      "dodge" => 52,
      "parry" => 90,
      "damage" => 80,
      "lvl" => 130
    },
    %{
      "action" => "$N大喝一声，手中的$w就如长虹一般向$n直劈而下",
      "force" => 380,
      "dodge" => 61,
      "parry" => 95,
      "damage" => 85,
      "lvl" => 150
    }
  ]

  @impl true
  def id(), do: "baisheng-daofa"

  @impl true
  def valid_enable(usage), do: usage in ["blade", "parry"]

  # LPC valid_learn 要求 max_neili>=600 / force>=100 / blade>=60 / blade>=baisheng-daofa（须持刀检查由 practice 流程把关）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 600 ->
        {:error, "你的内力不够。\n"}

      Stats.skill(stats, "force") < 100 ->
        {:error, "你的内功火候太浅。\n"}

      Stats.skill(stats, "blade") < 60 ->
        {:error, "你的基本刀法火候不够，无法学习百胜刀法。\n"}

      Stats.skill(stats, "blade") < Stats.skill(stats, id()) ->
        {:error, "你的基本刀法水平有限，无法领会更高深的百胜刀法。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 45 / neili 68（须持刀，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 45, neili: 68}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Skill.pick_action(@actions, level, rng)
  end

  @impl true
  def query_action(level, rng, _attacker), do: query_action(level, rng)

  @impl true
  def perform_list() do
    %{"heng" => Kantele.Combat.Skills.Performs.BaishengDaofa.Heng}
  end
  def actions(), do: @actions

end
