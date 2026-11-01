defmodule Kantele.Combat.Skills.ChuanyueJian do
  @moduledoc """
  穿月剑法（对照 `kungfu/skill/chuanyue-jian.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/chuanyue_jian/`。

  学习门槛 `valid_learn/2`（max_neili>=600 / force>=120 / sword>=100 / sword>=chuanyue-jian）与
  练招消耗 `practice_cost`（LPC 扣 qi 40 / neili 50，须持剑）已按 LPC 迁移（2026-10-30）。
  LPC 的须持剑（weapon skill_type=="sword"）检查由 practice 流程把关，未写入 `valid_learn`；招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N手中$w一转，回身一剑，刺向$n$l，正是一招「月挂长空」",
      "force" => 90,
      "attack" => 10,
      "dodge" => 21,
      "parry" => 25,
      "damage" => 22,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "只见$N身法陡然加快，施展出「剑气纵横」，剑风荡漾，$w瞬间已至$n$l",
      "force" => 100,
      "attack" => 12,
      "dodge" => 24,
      "parry" => 28,
      "damage" => 25,
      "lvl" => 25,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N纵身跃起，使出一招「晴空万里」，陡见$w从半空直指$N$l",
      "force" => 130,
      "attack" => 13,
      "dodge" => 25,
      "parry" => 31,
      "damage" => 38,
      "lvl" => 50,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N腾空而起，一招「月下山头」来势又准又快，手中$w已到$n$l",
      "force" => 150,
      "attack" => 15,
      "dodge" => 25,
      "parry" => 35,
      "damage" => 50,
      "lvl" => 75,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N剑峰忽转，一剑笔直地向$n$l刺来，内劲十足，正是一招「穿月无限」",
      "force" => 170,
      "attack" => 18,
      "dodge" => 27,
      "parry" => 38,
      "damage" => 63,
      "lvl" => 100,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N手中$w猛然回撤，紧接着一剑，气势磅礴，剑气纵横，正是「皓月穿空」",
      "force" => 200,
      "attack" => 20,
      "dodge" => 30,
      "parry" => 40,
      "damage" => 80,
      "lvl" => 120,
      "damage_type" => "刺伤"
    }
  ]

  @impl true
  def id(), do: "chuanyue-jian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "parry"]

  # LPC valid_learn 要求 max_neili>=600 / force>=120 / sword>=100 / sword>=chuanyue-jian
  # （须持剑检查 weapon skill_type=="sword" 沿用 practice 流程把关，未在此建模）

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 40 / neili 50（须持剑，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 40, neili: 50}

  # LPC `valid_learn(object me)`（源 chuanyue-jian.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      Skill.wielding?(character) and Skill.wielded_skill_type(character) != "sword" ->
        {:error, "你必须先找一把剑才能练剑法。\n"}

      not is_nil(max_neili) and max_neili < 600 ->
        {:error, "你的内力修为不够，无法学习穿月剑法。\n"}

      Stats.skill(stats, "force") < 120 ->
        {:error, "你的内功火候太浅，无法学习穿月剑法。\n"}

      Stats.skill(stats, "sword") < 100 ->
        {:error, "你的基本剑法火候不够，无法学习穿月剑法。\n"}

      Stats.skill(stats, "sword") < lvl ->
        {:error, "你的基本剑法火候有限，无法领会更高深的穿月剑法。\n"}

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
    %{"hao" => Kantele.Combat.Skills.Performs.ChuanyueJian.Hao}
  end
  def actions(), do: @actions

end
