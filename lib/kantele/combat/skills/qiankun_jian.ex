defmodule Kantele.Combat.Skills.QiankunJian do
  @moduledoc """
  乾坤剑法（对照 `kungfu/skill/qiankun-jian.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/qiankun_jian/`。

  学习门槛 `valid_learn/2`（force>=180 / max_neili>=2000 / sword>=150 / sword>=qiankun-jian）与
  练招消耗 `practice_cost`（LPC 扣 qi 65 / neili 70，须持剑）已按 LPC 迁移（2026-10-30）。
  LPC 的须持剑（weapon skill_type=="sword"）检查由 practice 流程把关，未写入 `valid_learn`；招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N手中的$w荡出，一招「太阳剑」，就如大江东去，势不可挡",
      "force" => 153,
      "attack" => 39,
      "dodge" => 65,
      "parry" => 67,
      "damage" => 41,
      "lvl" => 0,
      "skill_name" => "太阳剑"
    },
    %{
      "action" => "$N踏上一步，一招「少阴剑」，手中$w舞出一道剑光劈向$n的$l",
      "force" => 167,
      "attack" => 43,
      "dodge" => 68,
      "parry" => 69,
      "damage" => 43,
      "lvl" => 20,
      "skill_name" => "少阴剑"
    },
    %{
      "action" => "$N手中$w一抖，一招「少阳剑」，一剑刺向$n的$l，没有半点花巧",
      "force" => 173,
      "attack" => 48,
      "dodge" => 71,
      "parry" => 79,
      "damage" => 45,
      "lvl" => 40,
      "skill_name" => "少阳剑"
    },
    %{
      "action" => "$N手中$w微微颤动，一招「太阴剑」，忽然刺出，顿时一道剑光射向$n的$l",
      "force" => 195,
      "attack" => 51,
      "dodge" => 75,
      "parry" => 82,
      "damage" => 49,
      "lvl" => 60,
      "skill_name" => "太阴剑"
    },
    %{
      "action" => "$N身形一转，一招「天地定位」，横过$w，蓦然横扫$n，气势如宏",
      "force" => 218,
      "attack" => 57,
      "dodge" => 79,
      "parry" => 83,
      "damage" => 53,
      "lvl" => 80,
      "skill_name" => "天地定位"
    },
    %{
      "action" => "$N手中的$w连削带刺，一招「山泽通气」，夹带着一阵旋风掠过$n全身",
      "force" => 224,
      "attack" => 62,
      "dodge" => 85,
      "parry" => 89,
      "damage" => 57,
      "lvl" => 100,
      "skill_name" => "山泽通气"
    },
    %{
      "action" => "$N身形一转，一招「雷风相薄」，手中$w猛然攻下，蓦然横扫$n，气势如宏",
      "force" => 238,
      "attack" => 69,
      "dodge" => 87,
      "parry" => 91,
      "damage" => 61,
      "lvl" => 130,
      "skill_name" => "雷风相薄"
    },
    %{
      "action" => "$N手中的$w连削带刺，一招「水火不射」，夹带着一阵旋风掠过$n全身",
      "force" => 257,
      "attack" => 75,
      "dodge" => 95,
      "parry" => 99,
      "damage" => 68,
      "lvl" => 160,
      "skill_name" => "水火不射"
    },
    %{
      "action" => "$N身形一转，一招「八卦相错」，横转$w蓦然横扫$n，气势如宏",
      "force" => 270,
      "attack" => 81,
      "dodge" => 107,
      "parry" => 109,
      "damage" => 73,
      "lvl" => 190,
      "skill_name" => "八卦相错"
    },
    %{
      "action" => "$N手中的$w连削带刺，一招「乾坤无极」，夹带着一阵旋风掠过$n全身",
      "force" => 285,
      "attack" => 85,
      "dodge" => 115,
      "parry" => 115,
      "damage" => 77,
      "lvl" => 220,
      "skill_name" => "乾坤无极"
    }
  ]



  @ultimate %{
    "action" => "$N凝神静气，使出极招 乾坤神剑之极意",
    "lvl" => 300,
    "skill_name" => "极意"
  }
  @impl true
  def id(), do: "qiankun-jian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "parry"]

  # LPC valid_learn 要求 force>=180 / max_neili>=2000 / sword>=150 / sword>=qiankun-jian
  # （须持剑检查 weapon skill_type=="sword" 沿用 practice 流程把关，未在此建模）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      Stats.skill(stats, "force") < 180 ->
        {:error, "你的内功火候不到，无法学习乾坤神剑。\n"}

      not is_nil(max_neili) and max_neili < 2000 ->
        {:error, "你的内力太差，无法学习乾坤神剑。\n"}

      Stats.skill(stats, "sword") < 150 ->
        {:error, "你的基本剑法火候太浅，无法学习乾坤神剑。\n"}

      Stats.skill(stats, "sword") < Stats.skill(stats, id()) ->
        {:error, "你的基本剑法水平有限，无法领会更高深的乾坤神剑。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 65 / neili 70（须持剑，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 65, neili: 70}

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
      "ni" => Kantele.Combat.Skills.Performs.QiankunJian.Ni,
      "qian" => Kantele.Combat.Skills.Performs.QiankunJian.Qian,
      "riyue" => Kantele.Combat.Skills.Performs.QiankunJian.Riyue
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
