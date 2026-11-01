defmodule Kantele.Combat.Skills.XiyangJian do
  @moduledoc """
  夕阳剑法（对照 `kungfu/skill/xiyang-jian.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/xiyang_jian/`。

  学习门槛 `valid_learn/2`（max_neili>=100 / force>=30 / sword>=xiyang-jian）与
  练招消耗 `practice_cost`（LPC 扣 qi 70 / neili 40，须持剑）已按 LPC 迁移（2026-10-30）。
  LPC 的「须持剑（weapon skill_type=="sword"）」检查未在 `valid_learn` 建模
  （由 practice 流程把关），招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N双目怒睁，手中$w猛然刺出，疾若闪电",
      "force" => 100,
      "attack" => 35,
      "dodge" => 10,
      "parry" => 5,
      "damage" => 85,
      "lvl" => 0
    },
    %{
      "action" => "$N手中的$w不住的晃动，压向$n，忽然又横挑向$n的$l",
      "force" => 125,
      "attack" => 42,
      "dodge" => 10,
      "parry" => 15,
      "damage" => 100,
      "lvl" => 10
    },
    %{
      "action" => "$N手中的$w连续变换几个方向，最后突然直刺$n的$l",
      "force" => 150,
      "attack" => 45,
      "dodge" => 15,
      "parry" => 25,
      "damage" => 100,
      "lvl" => 30
    },
    %{
      "action" => "$N手中的$w猛然缩回，随即刺向$n，去势异常凶猛",
      "force" => 160,
      "attack" => 50,
      "dodge" => 25,
      "parry" => 29,
      "damage" => 110,
      "lvl" => 50
    },
    %{
      "action" => "$N手中$w一沉，斜斜的挑向$n的$l",
      "force" => 180,
      "attack" => 48,
      "dodge" => 20,
      "parry" => 31,
      "damage" => 115,
      "lvl" => 80
    },
    %{
      "action" => "$N大喝一声，手中的$w如闪电般刺出，化作满天剑影刺向$n",
      "force" => 240,
      "attack" => 52,
      "dodge" => 25,
      "parry" => 37,
      "damage" => 120,
      "lvl" => 100
    },
    %{
      "action" => "$N跨前几步，$w奋力前刺，义无反顾的攻向$n",
      "force" => 260,
      "attack" => 55,
      "dodge" => 15,
      "parry" => 37,
      "damage" => 125,
      "lvl" => 120
    },
    %{
      "action" => "$N猛然弯腰，手中$w忽然一亮，人剑合一飞刺向$n",
      "force" => 280,
      "attack" => 60,
      "dodge" => 30,
      "parry" => 45,
      "damage" => 130,
      "lvl" => 150
    }
  ]

  @impl true
  def id(), do: "xiyang-jian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "parry"]

  # LPC valid_learn 要求 max_neili>=100 / force>=30 / sword>=xiyang-jian
  # （须持剑检查 weapon skill_type=="sword" 沿用 practice 流程把关，未在此建模）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 100 ->
        {:error, "你的内力不够。\n"}

      Stats.skill(stats, "force") < 30 ->
        {:error, "你的内功火候不够。\n"}

      Stats.skill(stats, "sword") < Stats.skill(stats, id()) ->
        {:error, "你的基本剑法水平有限，无法领会更高深的西洋剑术。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 70 / neili 40（须持剑，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 70, neili: 40}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Skill.pick_action(@actions, level, rng)
  end

  @impl true
  def query_action(level, rng, _attacker), do: query_action(level, rng)

  @impl true
  def perform_list() do
    %{
      "ci" => Kantele.Combat.Skills.Performs.XiyangJian.Ci,
      "lian" => Kantele.Combat.Skills.Performs.XiyangJian.Lian
    }
  end
  def actions(), do: @actions

end
