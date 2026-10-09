defmodule Kantele.Combat.Skills.TianlongJian do
  @moduledoc """
  武学实装「tianlong-jian」（源 tianlong-jian.c，由 translate_skill.exs 生成）

  已自动化：静态招式 7 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/tianlong_jian/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N向前斜跨一步，一招「鲤跃龙门」，手中$w直刺$n的喉部",
      "force" => 126,
      "attack" => 0,
      "parry" => 3,
      "dodge" => 5,
      "damage" => 21,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "鲤跃龙门"
    },
    %{
      "action" => "$N错步上前，一招「神蛟初现」，剑意若有若无，$w淡淡地向$n的$l挥去",
      "force" => 149,
      "attack" => 0,
      "parry" => 13,
      "dodge" => 10,
      "damage" => 25,
      "lvl" => 20,
      "damage_type" => "割伤",
      "skill_name" => "神蛟初现"
    },
    %{
      "action" => "$N一式「电破长空」，纵身飘开数尺，运发剑气，手中$w遥摇指向$n的$l",
      "force" => 167,
      "attack" => 0,
      "parry" => 12,
      "dodge" => 15,
      "damage" => 31,
      "lvl" => 40,
      "damage_type" => "刺伤",
      "skill_name" => "电破长空"
    },
    %{
      "action" => "$N纵身轻轻跃起，一式「天龙探爪」，剑光如水，一泻千里，洒向$n全身",
      "force" => 187,
      "attack" => 0,
      "parry" => 23,
      "dodge" => 19,
      "damage" => 45,
      "lvl" => 60,
      "damage_type" => "割伤",
      "skill_name" => "天龙探爪"
    },
    %{
      "action" => "$N错步上前，一招「飞龙横空」，剑意若有若无，$w淡淡地向$n的$l挥去",
      "force" => 197,
      "attack" => 0,
      "parry" => 31,
      "dodge" => 27,
      "damage" => 56,
      "lvl" => 90,
      "damage_type" => "割伤",
      "skill_name" => "飞龙横空"
    },
    %{
      "action" => "$N手中$w中宫直进，一式「龙翔凤舞」，无声无息地对准$n的$l刺出一剑",
      "force" => 218,
      "attack" => 0,
      "parry" => 49,
      "dodge" => 35,
      "damage" => 63,
      "lvl" => 120,
      "damage_type" => "刺伤",
      "skill_name" => "龙翔凤舞"
    },
    %{
      "action" => "$N手中$w一沉，一式「天外游龙」，剑势顿时无声无息地滑向$n$l而去",
      "force" => 239,
      "attack" => 0,
      "parry" => 52,
      "dodge" => 45,
      "damage" => 72,
      "lvl" => 150,
      "damage_type" => "刺伤",
      "skill_name" => "天外游龙"
    }
  ]

  @impl true
  def id(), do: "tianlong-jian"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "sword"]

  @impl true
  def practice_cost(), do: %{qi: 52, neili: 53}

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
