defmodule Kantele.Combat.Skills.GuanriJian do
  @moduledoc """
  武学实装「guanri-jian」（源 guanri-jian.c，由 translate_skill.exs 生成）

  已自动化：静态招式 10 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/guanri_jian/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N左手$w轻送，施出观日剑法起手「日出东海」向前刺出，罩向$n的$l",
      "force" => 153,
      "attack" => 39,
      "parry" => 67,
      "dodge" => 65,
      "damage" => 41,
      "lvl" => 0,
      "damage_type" => "割伤",
      "skill_name" => "日出东海"
    },
    %{
      "action" => "$N剑尖倏地翻上，手中$w斜刺$n$l，正是观日剑法中「寰阳万钧」一招",
      "force" => 167,
      "attack" => 43,
      "parry" => 69,
      "dodge" => 68,
      "damage" => 43,
      "lvl" => 20,
      "damage_type" => "刺伤",
      "skill_name" => "寰阳万钧"
    },
    %{
      "action" => "$N一招「丹阳破虚」，剑尖一抖，$w中宫直进，剑到中途却变转剑锋斜削$n",
      "force" => 173,
      "attack" => 48,
      "parry" => 79,
      "dodge" => 71,
      "damage" => 45,
      "lvl" => 40,
      "damage_type" => "割伤",
      "skill_name" => "丹阳破虚"
    },
    %{
      "action" => "$N手中$w微微颤动，一招「赤日炎炎」，忽然刺出，顿时一道剑光射向$n而去",
      "force" => 195,
      "attack" => 51,
      "parry" => 82,
      "dodge" => 75,
      "damage" => 49,
      "lvl" => 60,
      "damage_type" => "刺伤",
      "skill_name" => "赤日炎炎"
    },
    %{
      "action" => "$N左手紧握剑指，右手$w紫光暴涨，一式「烽火绝尘」，剑指剑锋同时刺向$n",
      "force" => 218,
      "attack" => 57,
      "parry" => 83,
      "dodge" => 79,
      "damage" => 53,
      "lvl" => 80,
      "damage_type" => "刺伤",
      "skill_name" => "烽火绝尘"
    },
    %{
      "action" => "$N一式「洪峰万里」，$w划了一个半月弧形，洒出点点火光，直飞$n而去",
      "force" => 224,
      "attack" => 62,
      "parry" => 89,
      "dodge" => 85,
      "damage" => 57,
      "lvl" => 100,
      "damage_type" => "刺伤",
      "skill_name" => "洪峰万里"
    },
    %{
      "action" => "$N身形一转，一招「炼狱洪炉」，手中$w对着$n猛攻数剑，招式精奇之极",
      "force" => 238,
      "attack" => 69,
      "parry" => 91,
      "dodge" => 87,
      "damage" => 61,
      "lvl" => 130,
      "damage_type" => "割伤",
      "skill_name" => "炼狱洪炉"
    },
    %{
      "action" => "$N手中的$w连削带刺，一招「日照九天」，夹带着一阵炽热掠过$n全身",
      "force" => 257,
      "attack" => 75,
      "parry" => 99,
      "dodge" => 95,
      "damage" => 68,
      "lvl" => 160,
      "damage_type" => "刺伤",
      "skill_name" => "日照九天"
    },
    %{
      "action" => "$N一招「残阳血照」，使得若有若无，朦朦胧胧，$w斜斜划出，直取$n$l",
      "force" => 270,
      "attack" => 81,
      "parry" => 109,
      "dodge" => 107,
      "damage" => 73,
      "lvl" => 190,
      "damage_type" => "刺伤",
      "skill_name" => "残阳血照"
    },
    %{
      "action" => "$N长啸一声，一招「天火燎原」$w豪光绽放，剑尖顿时迸出数道剑气射向$n",
      "force" => 285,
      "attack" => 85,
      "parry" => 115,
      "dodge" => 115,
      "damage" => 77,
      "lvl" => 220,
      "damage_type" => "刺伤",
      "skill_name" => "天火燎原"
    }
  ]

  @impl true
  def id(), do: "guanri-jian"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "sword"]

  @impl true
  def practice_cost(), do: %{qi: 65, neili: 70}

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
      "fen" => Kantele.Combat.Skills.Performs.GuanriJian.Fen,
      "guan" => Kantele.Combat.Skills.Performs.GuanriJian.Guan
    }
  end
end
