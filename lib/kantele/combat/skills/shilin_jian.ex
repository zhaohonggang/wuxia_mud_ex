defmodule Kantele.Combat.Skills.ShilinJian do
  @moduledoc """
  武学实装「shilin-jian」（源 shilin-jian.c，由 translate_skill.exs 生成）

  已自动化：静态招式 5 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/shilin_jian/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N手中$w发出“嗖嗖”两声，$w斜刺$n$l，正是一招「书声朗朗」",
      "force" => 70,
      "attack" => 15,
      "parry" => 25,
      "dodge" => 38,
      "damage" => 20,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "书声朗朗"
    },
    %{
      "action" => "$N$w忽转，竟向$n的$l刺去，一式「岁岁青苍」已然使出",
      "force" => 85,
      "attack" => 28,
      "parry" => 40,
      "dodge" => 45,
      "damage" => 30,
      "lvl" => 25,
      "damage_type" => "刺伤",
      "skill_name" => "岁岁青苍"
    },
    %{
      "action" => "$N手中$w连续刺出三剑「剑出三生」，分向$n的面门，咽喉，和$l刺去",
      "force" => 120,
      "attack" => 40,
      "parry" => 45,
      "dodge" => 55,
      "damage" => 38,
      "lvl" => 50,
      "damage_type" => "刺伤",
      "skill_name" => "剑出三生"
    },
    %{
      "action" => "$N轻啸一声，一招「铺天盖地」，$w挽出一个剑花，剑光四射，洒向$n",
      "force" => 150,
      "attack" => 45,
      "parry" => 50,
      "dodge" => 65,
      "damage" => 45,
      "lvl" => 75,
      "damage_type" => "刺伤",
      "skill_name" => "铺天盖地"
    },
    %{
      "action" => "$N凝神聚气，猛然一剑刺出，不偏不倚，一招「石廪书声」直指$n$l",
      "force" => 180,
      "attack" => 55,
      "parry" => 60,
      "dodge" => 80,
      "damage" => 60,
      "lvl" => 100,
      "damage_type" => "刺伤",
      "skill_name" => "石廪书声"
    }
  ]

  @impl true
  def id(), do: "shilin-jian"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "sword"]

  @impl true
  def practice_cost(), do: %{qi: 45, neili: 55}

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
