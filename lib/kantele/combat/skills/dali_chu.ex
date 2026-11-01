defmodule Kantele.Combat.Skills.DaliChu do
  @moduledoc """
  大力锄法（对照 `kungfu/skill/dali-chu.c`）

  锄/锤法载体：`valid_enable("hammer")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/dali_chu/`。

  学习门槛 `valid_learn/2`（max_neili>=300 / force>=30 / hammer>=20 / hammer>=dali-chu）与
  练招消耗 `practice_cost`（LPC 扣 qi 35 / neili 40，须持锤）已按 LPC 迁移（2026-10-30）。
  LPC 的「须持锤（weapon skill_type=="hammer"）」检查未在 `valid_learn` 建模
  （由 practice 流程把关），招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N高高举起$w，施一招「天神降世」，狠狠的向$n的$l砸去",
      "force" => 110,
      "attack" => 2,
      "dodge" => -5,
      "parry" => -7,
      "damage" => 30,
      "lvl" => 0,
      "skill_name" => "天神降世"
    },
    %{
      "action" => "$N拔地而起，半空中一个筋斗，手中$w一式「崩山」扫向$n",
      "force" => 130,
      "attack" => 5,
      "dodge" => -11,
      "parry" => -5,
      "damage" => 40,
      "lvl" => 40,
      "skill_name" => "崩山"
    },
    %{
      "action" => "$N手中$w舞动，一招「力撼九天」挟着震天撞击之声，猛砸$n",
      "force" => 150,
      "attack" => 8,
      "dodge" => -6,
      "parry" => -5,
      "damage" => 45,
      "lvl" => 80,
      "skill_name" => "力撼九天"
    },
    %{
      "action" => "$N施一招「佛嗔」，手中$w呼呼有声，连续砸向$n的各个部位",
      "force" => 160,
      "attack" => 15,
      "dodge" => 0,
      "parry" => -3,
      "damage" => 50,
      "lvl" => 100,
      "skill_name" => "佛嗔"
    },
    %{
      "action" => "$N横过手中$w，使出「轰顶」，手中$w劈空而下，击向$n$l",
      "force" => 220,
      "attack" => 22,
      "dodge" => -10,
      "parry" => -5,
      "damage" => 75,
      "lvl" => 120,
      "skill_name" => "轰顶"
    }
  ]

  @impl true
  def id(), do: "dali-chu"

  @impl true
  def valid_enable(usage), do: usage in ["hammer", "parry"]

  # LPC valid_learn 要求 max_neili>=300 / force>=30 / hammer>=20 / hammer>=dali-chu（须持锤检查由 practice 流程把关）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 300 ->
        {:error, "你的内力修为不够，难以修炼无上大力杵。\n"}

      Stats.skill(stats, "force") < 30 ->
        {:error, "你的内功火候太浅，难以修炼无上大力杵。\n"}

      Stats.skill(stats, "hammer") < 20 ->
        {:error, "你的基本锤法不够，难以修炼无上大力杵。\n"}

      Stats.skill(stats, "hammer") < Stats.skill(stats, id()) ->
        {:error, "你的基本锤法水平有限，无法领会更高深的无上大力杵。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 35 / neili 40（须持锤，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 35, neili: 40}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Skill.pick_action(@actions, level, rng)
  end

  @impl true
  def query_action(level, rng, _attacker), do: query_action(level, rng)

  @impl true
  def perform_list() do
    %{"hong" => Kantele.Combat.Skills.Performs.DaliChu.Hong}
  end
  def actions(), do: @actions

end
