defmodule Kantele.Combat.Skills.PomopimaJian do
  @moduledoc """
  武学实装「pomopima-jian」（源 pomopima-jian.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/pomopima_jian/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N使一招「白虹贯日」，手中$w轻飘飘地向$n的$l刺去！",
      "force" => 120,
      "attack" => 0,
      "parry" => 14,
      "dodge" => 20,
      "damage" => 25,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "白虹贯日"
    },
    %{
      "action" => "$N金刃劈风，$w随著一招「腾蛟起风」由下而上撩往$n的$l",
      "force" => 140,
      "attack" => 0,
      "parry" => 15,
      "dodge" => 20,
      "damage" => 20,
      "lvl" => 20,
      "damage_type" => "刺伤",
      "skill_name" => "腾蛟起风"
    },
    %{
      "action" => "$N身形一转，一招「春风杨柳」$w剑光闪烁不定，刺向$n的$l",
      "force" => 155,
      "attack" => 0,
      "parry" => 16,
      "dodge" => 15,
      "damage" => 25,
      "lvl" => 40,
      "damage_type" => "刺伤",
      "skill_name" => "春风杨柳"
    },
    %{
      "action" => "$N舞动$w，一招「心驰神遥」迅捷无伦地射向$n的$l",
      "force" => 167,
      "attack" => 0,
      "parry" => 18,
      "dodge" => 15,
      "damage" => 35,
      "lvl" => 60,
      "damage_type" => "刺伤",
      "skill_name" => "心驰神遥"
    },
    %{
      "action" => "$N手中$w一晃，一招「青山依旧」往$n的$l斜斜刺出一剑",
      "force" => 170,
      "attack" => 0,
      "parry" => 21,
      "dodge" => 25,
      "damage" => 25,
      "lvl" => 80,
      "damage_type" => "刺伤",
      "skill_name" => "青山依旧"
    },
    %{
      "action" => "$N提剑过肩，蓄劲发力，一招「玉龙倒悬」直劈$n$l",
      "force" => 174,
      "attack" => 0,
      "parry" => 22,
      "dodge" => 25,
      "damage" => 25,
      "lvl" => 100,
      "damage_type" => "刺伤",
      "skill_name" => "玉龙倒悬"
    },
    %{
      "action" => "$N手中$w向外一分，一招「柳暗花明」反手对准$n$l一剑刺去",
      "force" => 189,
      "attack" => 0,
      "parry" => 35,
      "dodge" => 15,
      "damage" => 38,
      "lvl" => 120,
      "damage_type" => "刺伤",
      "skill_name" => "柳暗花明"
    },
    %{
      "action" => "$N移步侧身，使一招「漫山遍野」剑光霍霍完全笼罩$n的$l",
      "force" => 215,
      "attack" => 0,
      "parry" => 45,
      "dodge" => 35,
      "damage" => 43,
      "lvl" => 150,
      "damage_type" => "刺伤",
      "skill_name" => "漫山遍野"
    }
  ]

  @impl true
  def id(), do: "pomopima-jian"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "sword"]

  @impl true
  def practice_cost(), do: %{qi: 55, neili: 55}

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
