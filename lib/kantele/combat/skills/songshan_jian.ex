defmodule Kantele.Combat.Skills.SongshanJian do
  @moduledoc """
  嵩山剑法（对照 `kungfu/skill/songshan-jian.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/songshan_jian/`。

  学习门槛 `valid_learn/2`（max_neili>=100 / sword>=15 / sword>=songshan-jian）与
  练招消耗 `practice_cost`（LPC 扣 qi 45 / neili 30，须持剑）已按 LPC 迁移（2026-10-30）。
  LPC 的「须持剑（weapon skill_type=="sword"）」检查未在 `valid_learn` 建模
  （由 practice 流程把关），招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N手中$w忽地斜刺，嗡嗡作响，直指$n$l",
      "force" => 45,
      "dodge" => 28,
      "damage" => 5,
      "lvl" => 0
    },
    %{
      "action" => "$N手中$w反转，踏步向前，一剑刺向$n$l",
      "force" => 60,
      "dodge" => 24,
      "damage" => 8,
      "lvl" => 30
    },
    %{
      "action" => "寒光闪过，$N怒喝一声，飞身跃起，$w嗡嗡两声，已到$n$l",
      "force" => 80,
      "dodge" => 24,
      "damage" => 15,
      "lvl" => 60
    },
    %{
      "action" => "$N手中$w化出一道弧线，紧接着剑势收回，却平平一剑刺向$n$l",
      "force" => 100,
      "dodge" => 30,
      "damage" => 25,
      "lvl" => 80
    },
    %{
      "action" => "$N不慌不忙，猛地手中$w连续刺出，快如闪电，直指$n$l",
      "force" => 110,
      "dodge" => 38,
      "damage" => 30,
      "lvl" => 100
    }
  ]

  @impl true
  def id(), do: "songshan-jian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "parry"]

  # LPC valid_learn 要求 max_neili>=100 / sword>=15 / sword>=songshan-jian
  # （须持剑检查 weapon skill_type=="sword" 沿用 practice 流程把关，未在此建模）

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 45 / neili 30（须持剑，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 45, neili: 30}

  # LPC `valid_learn(object me)`（源 songshan-jian.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      Skill.wielding?(character) and Skill.wielded_skill_type(character) != "sword" ->
        {:error, "你必须先找一把剑才能练剑法。\n"}

      not is_nil(max_neili) and max_neili < 100 ->
        {:error, "你目前的内力修为不够，没有办法练嵩山剑法。\n"}

      Stats.skill(stats, "sword") < 15 ->
        {:error, "你的基本剑法火候太浅，没有办法练嵩山剑法。\n"}

      Stats.skill(stats, "sword") < lvl ->
        {:error, "你的基本剑法火候有限，无法领会更高深的绝情剑法。\n"}

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
    %{"meng" => Kantele.Combat.Skills.Performs.SongshanJian.Meng}
  end
  def actions(), do: @actions

end
