defmodule Kantele.Combat.Skills.WeituoGun do
  @moduledoc """
  武学实装「weituo-gun」（源 weituo-gun.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/weituo_gun/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N一招「黄石纳履」，手中$w如蜻蜓点水般，招招向$n的下盘要害点去",
      "force" => 120,
      "attack" => 25,
      "parry" => 30,
      "dodge" => 5,
      "damage" => 10,
      "lvl" => 0,
      "damage_type" => "挫伤",
      "skill_name" => "黄石纳履"
    },
    %{
      "action" => "$N把$w平提胸口，一拧身，一招「勒马停锋」，$w猛地撩向$n的颈部",
      "force" => 150,
      "attack" => 37,
      "parry" => 31,
      "dodge" => 5,
      "damage" => 15,
      "lvl" => 40,
      "damage_type" => "挫伤",
      "skill_name" => "勒马停锋"
    },
    %{
      "action" => "$N一招「平地龙飞」，全身滴溜溜地在地上打个大转，举棍向$n的胸腹间戳去",
      "force" => 180,
      "attack" => 42,
      "parry" => 37,
      "dodge" => 5,
      "damage" => 20,
      "lvl" => 80,
      "damage_type" => "挫伤",
      "skill_name" => "平地龙飞"
    },
    %{
      "action" => "$N伏地一个滚翻，一招「伏虎听风」，$w挟呼呼风声迅猛扫向$n的足胫",
      "force" => 210,
      "attack" => 43,
      "parry" => 35,
      "dodge" => 15,
      "damage" => 25,
      "lvl" => 100,
      "damage_type" => "挫伤",
      "skill_name" => "伏虎听风"
    },
    %{
      "action" => "$N一招「流星赶月」，身棍合一，棍端逼成一条直线，流星般向顶向$n的$l",
      "force" => 240,
      "attack" => 49,
      "parry" => 41,
      "dodge" => 20,
      "damage" => 30,
      "lvl" => 120,
      "damage_type" => "挫伤",
      "skill_name" => "流星赶月"
    },
    %{
      "action" => "$N双手持棍划了个天地大圈，一招「红霞贯日」，一棍从圆心正中击出，撞向$n的胸口",
      "force" => 270,
      "attack" => 58,
      "parry" => 45,
      "dodge" => 20,
      "damage" => 35,
      "lvl" => 140,
      "damage_type" => "挫伤",
      "skill_name" => "红霞贯日"
    },
    %{
      "action" => "$N一招「投鞭断流」，$w高举，以雷霆万钧之势对准$n的天灵当头劈下",
      "force" => 300,
      "attack" => 61,
      "parry" => 52,
      "dodge" => 25,
      "damage" => 40,
      "lvl" => 160,
      "damage_type" => "挫伤",
      "skill_name" => "投鞭断流"
    },
    %{
      "action" => "$N潜运真力，一招「苍龙归海」，$w顿时长了数丈，矫龙般直射$n的胸口",
      "force" => 320,
      "attack" => 63,
      "parry" => 55,
      "dodge" => 30,
      "damage" => 50,
      "lvl" => 180,
      "damage_type" => "挫伤",
      "skill_name" => "苍龙归海"
    }
  ]

  @impl true
  def id(), do: "weituo-gun"

  @impl true
  def valid_enable(usage), do: usage in ["club", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 62, neili: 61}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
  @doc "当前等级对应的最高招式名（query_skill_name）"
  def query_skill_name(level) do
    @actions
    |> Enum.reverse()
    |> Enum.find(fn action -> level >= Map.get(action, "lvl", 0) end)
    |> case do
      nil -> nil
      action -> Map.get(action, "skill_name")
    end
  end


  @impl true
  def perform_list() do
    %{
      "fumo" => Kantele.Combat.Skills.Performs.WeituoGun.Fumo
    }
  end
end
