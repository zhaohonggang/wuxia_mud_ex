defmodule Kantele.Combat.Skills.LuohanGun do
  @moduledoc """
  罗汉棍法（对照 `kungfu/skill/luohan-gun.c`）

  棍法载体：`valid_enable("club")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/luohan_gun/`。

  学习门槛 `valid_learn/2`（max_neili>=1200 / force>=100 / club>=100 /
  club>=luohan-gun）与练招消耗 `practice_cost`（LPC 扣 qi 62 / neili 61，须持棍）
  已按 LPC 迁移（2026-10-30）。LPC 的「须持棍（weapon skill_type=="club"）」检查
  未在 `valid_learn` 建模（由 practice 流程把关），招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N一招「罗汉问路」，手中$w如罗汉长手，招招向$n的下盘点去",
      "force" => 120,
      "attack" => 25,
      "dodge" => 5,
      "parry" => 30,
      "damage" => 10,
      "lvl" => 0,
      "skill_name" => "罗汉问路"
    },
    %{
      "action" => "$N把$w平提胸口，一拧身，一招「罗汉翻身」，$w猛地撩向$n的颈部",
      "force" => 150,
      "attack" => 37,
      "dodge" => 5,
      "parry" => 31,
      "damage" => 15,
      "lvl" => 40,
      "skill_name" => "罗汉翻身"
    },
    %{
      "action" => "$N一招「平地龙飞」，全身滴溜溜地在地上打个大转，举棍向$n的胸腹间戳去",
      "force" => 180,
      "attack" => 42,
      "dodge" => 5,
      "parry" => 37,
      "damage" => 20,
      "lvl" => 80,
      "skill_name" => "平地龙飞"
    },
    %{
      "action" => "$N伏地一个滚翻，一招「伏虎听风」，$w挟呼呼风声迅猛扫向$n的足胫",
      "force" => 210,
      "attack" => 43,
      "dodge" => 15,
      "parry" => 35,
      "damage" => 25,
      "lvl" => 100,
      "skill_name" => "伏虎听风"
    },
    %{
      "action" => "$N一招「流星赶月」，身棍合一，棍端逼成一条直线，流星般向顶向$n的$l",
      "force" => 240,
      "attack" => 49,
      "dodge" => 20,
      "parry" => 41,
      "damage" => 30,
      "lvl" => 120,
      "skill_name" => "流星赶月"
    },
    %{
      "action" => "$N双手持棍划了个天地大圈，一招「红霞贯日」，一棍从圆心正中击出，撞向$n的胸口",
      "force" => 270,
      "attack" => 58,
      "dodge" => 20,
      "parry" => 45,
      "damage" => 35,
      "lvl" => 140,
      "skill_name" => "红霞贯日"
    },
    %{
      "action" => "$N一招「投鞭断流」，$w高举，以雷霆万钧之势对准$n的天灵当头劈下",
      "force" => 300,
      "attack" => 61,
      "dodge" => 25,
      "parry" => 52,
      "lvl" => 160,
      "skill_name" => "投鞭断流"
    },
    %{
      "action" => "$N潜运真力，一招「苍龙归海」，$w顿时长了数丈，矫龙般直射$n的胸口",
      "force" => 320,
      "attack" => 63,
      "dodge" => 30,
      "parry" => 55,
      "damage" => 50,
      "lvl" => 180,
      "skill_name" => "苍龙归海"
    }
  ]

  @impl true
  def id(), do: "luohan-gun"

  @impl true
  def valid_enable(usage), do: usage in ["club", "parry"]

  # LPC valid_learn 要求 max_neili>=1200 / force>=100 / club>=100 / club>=luohan-gun
  # （须持棍检查 weapon skill_type=="club" 沿用 practice 流程把关，未在此建模）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 1200 ->
        {:error, "你的内力不够。\n"}

      Stats.skill(stats, "force") < 100 ->
        {:error, "你的内功火候太浅。\n"}

      Stats.skill(stats, "club") < 100 ->
        {:error, "你的基本棍法水平还不足以学习十八罗汉棍法。\n"}

      Stats.skill(stats, "club") < Stats.skill(stats, id()) ->
        {:error, "你的基本棍法水平有限，无法领会更高深的十八罗汉棍法。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 62 / neili 61（须持棍，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 62, neili: 61}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Skill.pick_action(@actions, level, rng)
  end

  @impl true
  def query_action(level, rng, _attacker), do: query_action(level, rng)

  @impl true
  def perform_list() do
    %{
      "shibaluohan" => Kantele.Combat.Skills.Performs.LuohanGun.Shibaluohan,
      "xiangmo" => Kantele.Combat.Skills.Performs.LuohanGun.Xiangmo
    }
  end
  def actions(), do: @actions

end
