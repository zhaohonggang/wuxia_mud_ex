defmodule Kantele.Combat.Skills.QuanzhenJian do
  @moduledoc """
  全真剑法（对照 `kungfu/skill/quanzhen-jian.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/quanzhen_jian/`。

  学习门槛 `valid_learn/2`（force>=150 / max_neili>=1000 / sword>=100 /
  sword>=quanzhen-jian）与练招消耗 `practice_cost`（LPC 扣 qi 55 / neili 53，须持剑）
  已按 LPC 迁移（2026-10-30）。LPC 的「须持剑（weapon skill_type=="sword"）」检查
  未在 `valid_learn` 建模（由 practice 流程把关），招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N使一式「探海屠龙」，手中$w由左至右横扫向向$n的$l",
      "force" => 70,
      "attack" => 10,
      "dodge" => 10,
      "damage" => 13,
      "lvl" => 0,
      "skill_name" => "探海屠龙"
    },
    %{
      "action" => "$N踏上一步，「罡风扫叶」，手中$w盘旋飞舞出一道剑光劈向$n的$l",
      "force" => 74,
      "attack" => 15,
      "dodge" => 20,
      "damage" => 19,
      "lvl" => 10,
      "skill_name" => "罡风扫叶"
    },
    %{
      "action" => "$N手中$w一抖，一招「顺水推舟」，斜斜一剑反腕撩出，攻向$n的$l",
      "force" => 85,
      "attack" => 20,
      "dodge" => 25,
      "damage" => 21,
      "lvl" => 20,
      "skill_name" => "顺水推舟"
    },
    %{
      "action" => "$N手中$w连绕数个大圈，一式「星弛电闪」，一道剑光飞向$n的$l",
      "force" => 118,
      "attack" => 25,
      "dodge" => 30,
      "damage" => 28,
      "lvl" => 40,
      "skill_name" => "星弛电闪"
    },
    %{
      "action" => "$N一式「白鹤亮翅」，左手伸展，右手$w挥向$n的$l",
      "force" => 130,
      "attack" => 30,
      "dodge" => 35,
      "damage" => 32,
      "lvl" => 60,
      "skill_name" => "白鹤亮翅"
    },
    %{
      "action" => "$N手中$w斜指苍天，一式「横行漠北」，对准$n的$l斜斜击出",
      "force" => 150,
      "attack" => 33,
      "dodge" => 45,
      "damage" => 39,
      "lvl" => 80,
      "skill_name" => "横行漠北"
    },
    %{
      "action" => "$N一式「马蹴落花」，手腕急抖，挥洒出万点金光，刺向$n的$l",
      "force" => 170,
      "attack" => 36,
      "dodge" => 42,
      "damage" => 48,
      "lvl" => 100,
      "skill_name" => "马蹴落花"
    },
    %{
      "action" => "$N一式「九品莲台」，$w飞斩盘旋，如疾电般射向$n的胸口",
      "force" => 193,
      "attack" => 40,
      "dodge" => 55,
      "damage" => 54,
      "lvl" => 120,
      "skill_name" => "九品莲台"
    },
    %{
      "action" => "$N使一式「荆轲刺秦」，手中$w合身疾刺$n的胸口，威不可当",
      "force" => 220,
      "attack" => 45,
      "dodge" => 55,
      "damage" => 63,
      "lvl" => 140,
      "skill_name" => "荆轲刺秦"
    },
    %{
      "action" => "$N手中$w划出一道长长的弧线，刺向$n的$l，却是一招「箫史乘龙」",
      "force" => 240,
      "attack" => 50,
      "dodge" => 58,
      "damage" => 75,
      "lvl" => 160,
      "skill_name" => "箫史乘龙"
    },
    %{
      "action" => "$N回剑自守，使一式「深藏若虚」，蓦地手中$w向$n击出",
      "force" => 280,
      "attack" => 55,
      "dodge" => 65,
      "damage" => 88,
      "lvl" => 180,
      "skill_name" => "深藏若虚"
    },
    %{
      "action" => "$N左足踢起，一式「魁星踢斗」，$w从不可思议的角度刺向$n",
      "force" => 340,
      "attack" => 57,
      "dodge" => 62,
      "damage" => 103,
      "lvl" => 200,
      "skill_name" => "魁星踢斗"
    },
    %{
      "action" => "$N一式「紫电穿云」，$w突然从天而降，一片金光围掠$n全身",
      "force" => 370,
      "attack" => 60,
      "dodge" => 66,
      "damage" => 135,
      "lvl" => 220,
      "skill_name" => "紫电穿云"
    }
  ]



  @ultimate %{
    "action" => "$N凝神静气，使出极招 全真剑法之极意",
    "lvl" => 300,
    "skill_name" => "极意"
  }
  @impl true
  def id(), do: "quanzhen-jian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "parry"]

  # LPC valid_learn 要求 force>=150 / max_neili>=1000 / sword>=100 / sword>=quanzhen-jian
  # （须持剑检查 weapon skill_type=="sword" 沿用 practice 流程把关，未在此建模）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      Stats.skill(stats, "force") < 150 ->
        {:error, "你的内功火候不足，无法学习全真剑法。\n"}

      not is_nil(max_neili) and max_neili < 1000 ->
        {:error, "你的内力修为太差，无法学习全真剑法。\n"}

      Stats.skill(stats, "sword") < 100 ->
        {:error, "你的基本剑法修为不够，无法学习全真剑法。\n"}

      Stats.skill(stats, "sword") < Stats.skill(stats, id()) ->
        {:error, "你的基本剑法水平有限，无法领会更高深的全真剑法。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 55 / neili 53（须持剑，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 55, neili: 53}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Skill.pick_action(@actions, level, rng)
  end

  @impl true
  def query_action(level, rng, attacker) do
    Skill.pick_action_with_ultimate(
      @actions,
      level,
      attacker,
      @ultimate,
      &ultimate_values/2,
      rng
    )
  end

  @impl true
  def perform_list() do
    %{
      "chan" => Kantele.Combat.Skills.Performs.QuanzhenJian.Chan,
      "ding" => Kantele.Combat.Skills.Performs.QuanzhenJian.Ding,
      "hua" => Kantele.Combat.Skills.Performs.QuanzhenJian.Hua,
      "lian" => Kantele.Combat.Skills.Performs.QuanzhenJian.Lian
    }
  end
  def actions(), do: @actions

  defp ultimate_values(attacker, rng) do
    dodge = Skill.skill_of(attacker, "dodge")
    force = Skill.skill_of(attacker, "force")
    parry = Skill.skill_of(attacker, "parry")
    sword = Skill.skill_of(attacker, "sword")
    r = &Skill.lpc_random(rng, &1)
    %{
      "force" => div(force, 2) + r.(force),
      "attack" => div(sword, 4) + r.(div(sword, 2)),
      "dodge" => div(dodge, 6) + r.(div(force, 3)),
      "parry" => div(parry, 6) + r.(div(parry, 3)),
      "damage" => div(force, 4) + r.(div(force, 2))
    }
  end

end
