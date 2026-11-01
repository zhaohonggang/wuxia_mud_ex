defmodule Kantele.Combat.Skills.QishiJi do
  @moduledoc """
  齐氏戟法（对照 `kungfu/skill/qishi-ji.c`）

  戟/棍法载体：`valid_enable("club")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/qishi_ji/`。

  学习门槛 `valid_learn/2`（max_neili>=100 / force>=30 / club>=self）与练招消耗
  `practice_cost`（qi 70 / neili 40）已按 LPC 迁移（2026-10-30）。须持戟检查由 practice 流程把关；LPC 重复行已合并，末门文案 verbatim「基本剑法」保真不修；招式表已从 LPC 迁移。
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
      "action" => "$N双手所持的$w转动不已，猛的疾刺向$n而去",
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
      "action" => "$N跨前一不，双手将$w一压，斜斜的挑向$n的$l",
      "force" => 180,
      "attack" => 48,
      "dodge" => 20,
      "parry" => 31,
      "damage" => 115,
      "lvl" => 80
    },
    %{
      "action" => "$N大喝一声，$w便如闪电般刺出，携着一股旋风刺向$n",
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
    }
  ]

  @impl true
  def id(), do: "qishi-ji"

  @impl true
  def valid_enable(usage), do: usage in ["club", "parry"]

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili), do: max_neili
  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 70 / neili 40（须持戟，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 70, neili: 40}

  # LPC `valid_learn(object me)`（源 qishi-ji.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 100 ->
        {:error, "你的内力不够。\n"}

      Stats.skill(stats, "force") < 30 ->
        {:error, "你的内功火候不够。\n"}

      Stats.skill(stats, "club") < lvl ->
        {:error, "你的基本剑法水平有限，无法领会更高深的圣骑士戟。\n"}

      Stats.skill(stats, "club") < lvl ->
        {:error, "你的基本剑法水平有限，无法领会更高深的圣骑士戟。\n"}

      true ->
        :ok
    end
  end

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Skill.pick_action(@actions, level, rng)
  end

  @impl true
  def query_action(level, rng, _attacker), do: query_action(level, rng)

  @impl true
  def perform_list() do
    %{
      "chong" => Kantele.Combat.Skills.Performs.QishiJi.Chong,
      "juan" => Kantele.Combat.Skills.Performs.QishiJi.Juan
    }
  end
  def actions(), do: @actions

end
