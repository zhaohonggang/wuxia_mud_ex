defmodule Kantele.Combat.Skills.GuxingJian do
  @moduledoc """
  孤星剑法（对照 `kungfu/skill/guxing-jian.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/guxing_jian/`。

  学习门槛 `valid_learn/2`（max_neili>=400 / force>=100 / sword>=80 / sword>=guxing-jian）与
  练招消耗 `practice_cost`（LPC 扣 qi 45 / neili 35，须持剑）已按 LPC 迁移（2026-10-30）。
  LPC 的须持剑（weapon skill_type=="sword"）检查由 practice 流程把关，未写入 `valid_learn`；招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N手中$w快速猛刺，连连逼迫向$n",
      "force" => 80,
      "dodge" => 28,
      "damage" => 20,
      "lvl" => 0
    },
    %{
      "action" => "$N手中$w横向一扫，一式「神龙摆尾」，剑光闪过，刹那间$w已到$n$l",
      "force" => 90,
      "dodge" => 24,
      "damage" => 25,
      "lvl" => 30
    },
    %{
      "action" => "剑光不定，$N忽地反转剑身，一式「昙花一现」，猛然间$w刺向$n$l",
      "force" => 100,
      "dodge" => 24,
      "damage" => 30,
      "lvl" => 60
    },
    %{
      "action" => "$N不进反退，一式「逆水行舟」，$w倒握于手中，却斜身一剑指向$n",
      "force" => 120,
      "dodge" => 30,
      "damage" => 35,
      "lvl" => 90
    },
    %{
      "action" => "$N飞身跃起，手中$w一横，一式「横扫千军」，力道非凡，袭向$n$l",
      "force" => 140,
      "dodge" => 40,
      "damage" => 40,
      "lvl" => 120
    }
  ]

  @impl true
  def id(), do: "guxing-jian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "parry"]

  # LPC valid_learn 要求 max_neili>=400 / force>=100 / sword>=80 / sword>=guxing-jian
  # （须持剑检查 weapon skill_type=="sword" 沿用 practice 流程把关，未在此建模）

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 45 / neili 35（须持剑，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 45, neili: 35}

  # LPC `valid_learn(object me)`（源 guxing-jian.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      Skill.wielding?(character) and Skill.wielded_skill_type(character) != "sword" ->
        {:error, "你必须先找一把剑才能练剑法。\n"}

      not is_nil(max_neili) and max_neili < 400 ->
        {:error, "你目前的内力修为不够，没有办法练孤星剑法。\n"}

      Stats.skill(stats, "force") < 100 ->
        {:error, "你的内功修为不够，没有办法练孤星剑法。\n"}

      Stats.skill(stats, "sword") < 80 ->
        {:error, "你的基本剑法火候太浅，没有办法练孤星剑法。\n"}

      Stats.skill(stats, "sword") < lvl ->
        {:error, "你的基本剑法火候有限，无法领会更高深的孤星剑法。\n"}

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
    %{"lian" => Kantele.Combat.Skills.Performs.GuxingJian.Lian}
  end
  def actions(), do: @actions

end
