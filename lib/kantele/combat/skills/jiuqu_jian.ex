defmodule Kantele.Combat.Skills.JiuquJian do
  @moduledoc """
  九曲剑法（对照 `kungfu/skill/jiuqu-jian.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/jiuqu_jian/`。

  学习门槛 `valid_learn/2`（max_neili>=300 / force>=100 / sword>=60 / sword>=jiuqu-jian）与
  练招消耗 `practice_cost`（LPC 扣 qi 40 / neili 50，须持剑）已按 LPC 迁移（2026-10-30）。
  LPC 的须持剑（weapon skill_type=="sword"，valid_learn 与 practice_skill 均检查）由 practice 流程把关，未写入 `valid_learn`；招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N左晃右蹿，手中$w突然刺向$n$l，正是一招「千沟万壑」",
      "force" => 45,
      "attack" => 10,
      "dodge" => 20,
      "parry" => 20,
      "damage" => 20,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N越攻越猛，突然间手中$w剑光暴涨，一招「峰回路转」已然使出\n$n只觉眼前剑光耀眼，不由得心中一惊",
      "force" => 90,
      "attack" => 24,
      "dodge" => 26,
      "parry" => 40,
      "damage" => 35,
      "lvl" => 25,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N以攻为守，以进为退，手中$w刷的一剑「天外飞凤」，向$n$l刺去",
      "force" => 110,
      "attack" => 30,
      "dodge" => 35,
      "parry" => 40,
      "damage" => 40,
      "lvl" => 50,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N轻啸一声，$w径直向$n$w，这一剑虽无任何招式，但是$N却使得不\n卑不亢，毫无滞带，将「千山暮雪」这一招发挥到了及至",
      "force" => 120,
      "attack" => 35,
      "dodge" => 48,
      "parry" => 45,
      "damage" => 48,
      "lvl" => 75,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N将$w一挥，长啸一声，腾空而起，使出一式「神风式」！这一招来得又\n快又准，$w直指$n$l,",
      "force" => 130,
      "attack" => 55,
      "dodge" => 56,
      "parry" => 66,
      "damage" => 60,
      "lvl" => 100,
      "damage_type" => "刺伤"
    }
  ]

  @impl true
  def id(), do: "jiuqu-jian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "parry"]

  # LPC valid_learn 要求 max_neili>=300 / force>=100 / sword>=60 / sword>=jiuqu-jian
  # （须持剑检查 weapon skill_type=="sword" 沿用 practice 流程把关，未在此建模）

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 40 / neili 50（须持剑，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 40, neili: 50}

  # LPC `valid_learn(object me)`（源 jiuqu-jian.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      Skill.wielding?(character) and Skill.wielded_skill_type(character) != "sword" ->
        {:error, "你必须先找一把剑才能练剑法。\n"}

      not is_nil(max_neili) and max_neili < 300 ->
        {:error, "你的内力不够，没有办法练九曲剑法。\n"}

      Stats.skill(stats, "force") < 100 ->
        {:error, "你的内功火候太浅。\n"}

      Stats.skill(stats, "sword") < 60 ->
        {:error, "你的基本剑法火候不够，无法学习九曲剑法。\n"}

      Stats.skill(stats, "sword") < lvl ->
        {:error, "你的基本剑法火候有限，无法领会更高深的九曲剑法。\n"}

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
    %{"wan" => Kantele.Combat.Skills.Performs.JiuquJian.Wan}
  end
  def actions(), do: @actions

end
