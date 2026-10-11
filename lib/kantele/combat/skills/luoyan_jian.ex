defmodule Kantele.Combat.Skills.LuoyanJian do
  @moduledoc """
  武学实装「luoyan-jian」（源 luoyan-jian.c，由 translate_skill.exs 生成）

  已自动化：静态招式 6 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/luoyan_jian/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N手中$w一转，回身一剑，刺向$n$l，正是一招「回剑式」",
      "force" => 56,
      "attack" => 10,
      "parry" => 25,
      "dodge" => 21,
      "damage" => 12,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "回剑式"
    },
    %{
      "action" => "只见$N身法陡然加快，施展出「拂风式」，剑风荡漾，$w瞬间已至$n$l",
      "force" => 69,
      "attack" => 12,
      "parry" => 28,
      "dodge" => 24,
      "damage" => 15,
      "lvl" => 25,
      "damage_type" => "刺伤",
      "skill_name" => "拂风式"
    },
    %{
      "action" => "$N纵身跃起，使出一招「落剑式」，陡见$w从半空直指$N$l",
      "force" => 81,
      "attack" => 13,
      "parry" => 31,
      "dodge" => 25,
      "damage" => 18,
      "lvl" => 50,
      "damage_type" => "刺伤",
      "skill_name" => "落剑式"
    },
    %{
      "action" => "$N腾空而起，一招「雁翔式」来势又准又快，手中$w已到$n$l",
      "force" => 93,
      "attack" => 15,
      "parry" => 35,
      "dodge" => 25,
      "damage" => 20,
      "lvl" => 75,
      "damage_type" => "刺伤",
      "skill_name" => "雁翔式"
    },
    %{
      "action" => "$N剑峰忽转，一剑笔直地向$n$l刺来，内劲十足，正是一招「平剑式」",
      "force" => 106,
      "attack" => 18,
      "parry" => 38,
      "dodge" => 27,
      "damage" => 23,
      "lvl" => 100,
      "damage_type" => "刺伤",
      "skill_name" => "平剑式"
    },
    %{
      "action" => "$N手中$w猛然回撤，紧接着一剑，气势磅礴，剑气纵横，正是「凝剑式」",
      "force" => 120,
      "attack" => 20,
      "parry" => 40,
      "dodge" => 30,
      "damage" => 25,
      "lvl" => 120,
      "damage_type" => "刺伤",
      "skill_name" => "凝剑式"
    }
  ]

  @impl true
  def id(), do: "luoyan-jian"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "sword"]

  @impl true
  def practice_cost(), do: %{qi: 40, neili: 50}

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
      "luo" => Kantele.Combat.Skills.Performs.LuoyanJian.Luo
    }
  end
end
