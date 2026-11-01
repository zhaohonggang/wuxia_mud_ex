defmodule Kantele.Combat.Skills.PanlongSuo do
  @moduledoc """
  盘龙索法（对照 `kungfu/skill/panlong-suo.c`）

  鞭/索法载体：`valid_enable("whip")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/panlong_suo/`。

  学习门槛 `valid_learn/2`（max_neili>=800 / force>=120 / whip>=80 / whip>=self）与练招消耗
  `practice_cost`（qi 75 / neili 85）已按 LPC 迁移（2026-10-30）。LPC valid_learn 的「须持鞭」检查由 practice 流程把关；招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N端坐不动，一招「破元势」，手中$w抖得笔直，对准$n的胸腹要害连刺数鞭",
      "force" => 180,
      "attack" => 20,
      "dodge" => 2,
      "parry" => 1,
      "damage" => 49,
      "lvl" => 0,
      "skill_name" => "破元势"
    },
    %{
      "action" => "$N身形一转，一招「吞金势」，手中$w如矫龙般腾空一卷，猛地向$n劈头打下",
      "force" => 200,
      "attack" => 28,
      "dodge" => 3,
      "parry" => 5,
      "damage" => 61,
      "lvl" => 30,
      "skill_name" => "吞金势"
    },
    %{
      "action" => "$N力贯鞭梢，一招「荡妖势」，手中$w舞出满天鞭影，排山倒海般扫向$n全身",
      "force" => 210,
      "attack" => 35,
      "dodge" => 2,
      "parry" => 5,
      "damage" => 73,
      "lvl" => 60,
      "skill_name" => "荡妖势"
    },
    %{
      "action" => "$N力贯鞭梢，一招「伏魔势」，手中$w舞出满天鞭影，排山倒海般扫向$n全身",
      "force" => 220,
      "attack" => 41,
      "dodge" => 5,
      "parry" => 6,
      "damage" => 84,
      "lvl" => 90,
      "skill_name" => "伏魔势"
    },
    %{
      "action" => "$N力贯鞭梢，一招「寰穹势」，手中$w舞出满天鞭影，排山倒海般扫向$n全身",
      "force" => 230,
      "attack" => 47,
      "dodge" => 6,
      "parry" => 15,
      "damage" => 95,
      "lvl" => 120,
      "skill_name" => "寰穹势"
    },
    %{
      "action" => "$N力贯鞭梢，一招「戮神势」，手中$w舞出满天鞭影，排山倒海般扫向$n全身",
      "force" => 240,
      "attack" => 55,
      "dodge" => 12,
      "parry" => 20,
      "damage" => 110,
      "lvl" => 150,
      "skill_name" => "戮神势"
    },
    %{
      "action" => "$N力贯鞭梢，一招「雷轰势」，手中$w舞出满天鞭影，排山倒海般扫向$n全身",
      "force" => 260,
      "attack" => 61,
      "dodge" => 17,
      "parry" => 25,
      "damage" => 130,
      "lvl" => 180,
      "skill_name" => "雷轰势"
    },
    %{
      "action" => "$N力贯鞭梢，一招「盘龙势」，手中$w舞出满天鞭影，排山倒海般扫向$n全身",
      "force" => 290,
      "attack" => 68,
      "dodge" => 20,
      "parry" => 35,
      "damage" => 149,
      "lvl" => 220,
      "skill_name" => "盘龙势"
    }
  ]

  @impl true
  def id(), do: "panlong-suo"

  @impl true
  def valid_enable(usage), do: usage in ["whip", "parry"]

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili), do: max_neili
  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 75 / neili 85（须持鞭，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 75, neili: 85}

  # LPC `valid_learn(object me)`（源 panlong-suo.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      Skill.wielding?(character) and Skill.wielded_skill_type(character) != "whip" ->
        {:error, "你必须先找一条鞭子才能练鞭法。\n"}

      not is_nil(max_neili) and max_neili < 800 ->
        {:error, "你的内力修为不足，无法修炼霹雳盘龙索。\n"}

      Stats.skill(stats, "force") < 120 ->
        {:error, "你的内功火候太浅，无法修炼霹雳盘龙索。\n"}

      Stats.skill(stats, "whip") < 80 ->
        {:error, "你的基本鞭法火候太浅，无法修炼霹雳盘龙索。\n"}

      Stats.skill(stats, "whip") < lvl ->
        {:error, "你的基本鞭法水平还不够，无法领会更高深的霹雳盘龙索。\n"}

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
      "chan" => Kantele.Combat.Skills.Performs.PanlongSuo.Chan,
      "sha" => Kantele.Combat.Skills.Performs.PanlongSuo.Sha
    }
  end
  def actions(), do: @actions

end
