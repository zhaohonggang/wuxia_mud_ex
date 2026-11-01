defmodule Kantele.Combat.Skills.PoguangDao do
  @moduledoc """
  破光刀法（对照 `kungfu/skill/poguang-dao.c`）

  刀法载体：`valid_enable("blade")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/poguang_dao/`。

  学习门槛 `valid_learn/2`（max_neili>=800 / force>=120 / blade>=100 / blade>=poguang-dao）与
  练招消耗 `practice_cost`（LPC 扣 qi 40 / neili 50）已按 LPC 迁移（2026-10-30）。
  LPC 原文不一致：`valid_learn` 要求持刀（blade），而 `practice_skill` 检查 sword；武器检查照前批由 practice 流程把关，未写入 `valid_learn`；招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N手中$w横空而出，一式「破空式」，$w已到$n$l",
      "force" => 90,
      "attack" => 10,
      "dodge" => 21,
      "parry" => 25,
      "damage" => 22,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N手中$w平平挥出，一式「横空式」，$w砍向$n$l",
      "force" => 100,
      "attack" => 12,
      "dodge" => 24,
      "parry" => 28,
      "damage" => 25,
      "lvl" => 25,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N纵身跃起，施出一式「冷光式」，$w寒光一闪已到$n$l",
      "force" => 120,
      "attack" => 13,
      "dodge" => 25,
      "parry" => 31,
      "damage" => 38,
      "lvl" => 50,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N腾空而起，一式「穿阳式」，手中$w直砍向$n$l",
      "force" => 140,
      "attack" => 15,
      "dodge" => 25,
      "parry" => 35,
      "damage" => 50,
      "lvl" => 75,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N刀峰忽转，施出一式「回旋式」，$w蜿蜒而进，袭向$n$l",
      "force" => 160,
      "attack" => 18,
      "dodge" => 27,
      "parry" => 38,
      "damage" => 63,
      "lvl" => 100,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N怒喝一声，手中$w狂舞不定，一式「狂风式」，如无数把$w罩向$n",
      "force" => 180,
      "attack" => 20,
      "dodge" => 30,
      "parry" => 40,
      "damage" => 80,
      "lvl" => 120,
      "damage_type" => "刺伤"
    }
  ]

  @impl true
  def id(), do: "poguang-dao"

  @impl true
  def valid_enable(usage), do: usage in ["blade", "parry"]

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 40 / neili 50（须持武器，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 40, neili: 50}

  # LPC `valid_learn(object me)`（源 poguang-dao.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      Skill.wielding?(character) and Skill.wielded_skill_type(character) != "blade" ->
        {:error, "你必须先找一把刀才能练破光刀法。\n"}

      not is_nil(max_neili) and max_neili < 800 ->
        {:error, "你的内力修为不够，无法学习破光刀法。\n"}

      Stats.skill(stats, "force") < 120 ->
        {:error, "你的内功火候太浅，无法学习破光刀法。\n"}

      Stats.skill(stats, "blade") < 100 ->
        {:error, "你的基本刀法火候不够，无法学习破光刀法。\n"}

      Stats.skill(stats, "blade") < lvl ->
        {:error, "你的基本剑法火候有限，无法领会更高深的破光刀法。\n"}

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
      "bing" => Kantele.Combat.Skills.Performs.PoguangDao.Bing,
      "yang" => Kantele.Combat.Skills.Performs.PoguangDao.Yang
    }
  end
  def actions(), do: @actions

end
