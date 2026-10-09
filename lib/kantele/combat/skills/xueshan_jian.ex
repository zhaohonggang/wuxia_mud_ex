defmodule Kantele.Combat.Skills.XueshanJian do
  @moduledoc """
  武学实装「xueshan-jian」（源 xueshan-jian.c，由 translate_skill.exs 生成）

  已自动化：静态招式 10 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/xueshan_jian/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N左手$w轻送，施出雪山剑法起手「朝天势」向前刺出，罩向$n的$l",
      "force" => 153,
      "attack" => 39,
      "parry" => 67,
      "dodge" => 65,
      "damage" => 41,
      "lvl" => 0,
      "damage_type" => "割伤",
      "skill_name" => "朝天势"
    },
    %{
      "action" => "$N剑尖倏地翻上，手中$w斜刺$n$l，正是雪山派剑法中「老枝横斜」一招",
      "force" => 167,
      "attack" => 43,
      "parry" => 69,
      "dodge" => 68,
      "damage" => 43,
      "lvl" => 20,
      "damage_type" => "刺伤",
      "skill_name" => "老枝横斜"
    },
    %{
      "action" => "$N一招「雪泥鸿爪」，剑尖一抖，$w中宫直进，剑到中途却变转剑锋，斜削$n",
      "force" => 173,
      "attack" => 48,
      "parry" => 79,
      "dodge" => 71,
      "damage" => 45,
      "lvl" => 40,
      "damage_type" => "割伤",
      "skill_name" => "雪泥鸿爪"
    },
    %{
      "action" => "$N手中$w微微颤动，一招「朔风忽起」，忽然刺出，顿时一道剑光射向$n的$l",
      "force" => 195,
      "attack" => 51,
      "parry" => 82,
      "dodge" => 75,
      "damage" => 49,
      "lvl" => 60,
      "damage_type" => "刺伤",
      "skill_name" => "朔风忽起"
    },
    %{
      "action" => "$N左手紧握剑指，右手$w上隐隐透出青气，一式「岭上双梅」，剑指剑锋同时刺向$n",
      "force" => 218,
      "attack" => 57,
      "parry" => 83,
      "dodge" => 79,
      "damage" => 53,
      "lvl" => 80,
      "damage_type" => "刺伤",
      "skill_name" => "岭上双梅"
    },
    %{
      "action" => "$N一式「明驼西来」，$w划了一个半月弧形，洒出点点银光，直飞$n$l而去",
      "force" => 224,
      "attack" => 62,
      "parry" => 89,
      "dodge" => 85,
      "damage" => 57,
      "lvl" => 100,
      "damage_type" => "刺伤",
      "skill_name" => "明驼西来"
    },
    %{
      "action" => "$N身形一转，一招「梅雪争春」，手中$w对着$n猛攻数剑，招式精奇，荡气回肠",
      "force" => 238,
      "attack" => 69,
      "parry" => 91,
      "dodge" => 87,
      "damage" => 61,
      "lvl" => 130,
      "damage_type" => "割伤",
      "skill_name" => "梅雪争春"
    },
    %{
      "action" => "$N手中的$w连削带刺，一招「暗香疏影」，夹带着一阵旋风掠过$n全身",
      "force" => 257,
      "attack" => 75,
      "parry" => 99,
      "dodge" => 95,
      "damage" => 68,
      "lvl" => 160,
      "damage_type" => "刺伤",
      "skill_name" => "暗香疏影"
    },
    %{
      "action" => "$N一招「月色黄昏」，使得若有若无，朦朦胧胧，$w斜斜划出，直取$n$l",
      "force" => 270,
      "attack" => 81,
      "parry" => 109,
      "dodge" => 107,
      "damage" => 73,
      "lvl" => 190,
      "damage_type" => "刺伤",
      "skill_name" => "月色黄昏"
    },
    %{
      "action" => "$N长啸一声，一招「鹤飞九天」，手中$w豪光绽放，剑尖顿时迸出数道剑气射向$n",
      "force" => 285,
      "attack" => 85,
      "parry" => 115,
      "dodge" => 115,
      "damage" => 77,
      "lvl" => 220,
      "damage_type" => "刺伤",
      "skill_name" => "鹤飞九天"
    }
  ]

  @impl true
  def id(), do: "xueshan-jian"

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

end
