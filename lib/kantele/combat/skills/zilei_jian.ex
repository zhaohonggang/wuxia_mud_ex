defmodule Kantele.Combat.Skills.ZileiJian do
  @moduledoc """
  武学实装「zilei-jian」（源 zilei-jian.c，由 translate_skill.exs 生成）

  已自动化：静态招式 6 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/zilei_jian/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N手中$w一转，回身一剑，刺向$n$l，正是一招「万紫千红」",
      "force" => 90,
      "attack" => 10,
      "parry" => 25,
      "dodge" => 21,
      "damage" => 22,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "万紫千红"
    },
    %{
      "action" => "只见$N身法陡然加快，施展出「风雨交加」，剑风荡漾，$w瞬间已至$n$l",
      "force" => 100,
      "attack" => 12,
      "parry" => 28,
      "dodge" => 24,
      "damage" => 25,
      "lvl" => 25,
      "damage_type" => "刺伤",
      "skill_name" => "风雨交加"
    },
    %{
      "action" => "$N纵身跃起，使出一招「晴空万里」，陡见$w从半空直指$N$l",
      "force" => 120,
      "attack" => 13,
      "parry" => 31,
      "dodge" => 25,
      "damage" => 38,
      "lvl" => 50,
      "damage_type" => "刺伤",
      "skill_name" => "晴空万里"
    },
    %{
      "action" => "$N腾空而起，一招「狂风暴雨」来势又准又快，手中$w已到$n$l",
      "force" => 140,
      "attack" => 15,
      "parry" => 35,
      "dodge" => 25,
      "damage" => 50,
      "lvl" => 75,
      "damage_type" => "刺伤",
      "skill_name" => "狂风暴雨"
    },
    %{
      "action" => "$N剑峰忽转，一剑笔直地向$n$l刺来，内劲十足，正是一招「雨过天晴」",
      "force" => 160,
      "attack" => 18,
      "parry" => 38,
      "dodge" => 27,
      "damage" => 63,
      "lvl" => 100,
      "damage_type" => "刺伤",
      "skill_name" => "雨过天晴"
    },
    %{
      "action" => "$N手中$w猛然回撤，紧接着一剑，气势磅礴，剑气纵横，正是「电闪雷鸣」",
      "force" => 180,
      "attack" => 20,
      "parry" => 40,
      "dodge" => 30,
      "damage" => 80,
      "lvl" => 120,
      "damage_type" => "刺伤",
      "skill_name" => "电闪雷鸣"
    }
  ]

  @impl true
  def id(), do: "zilei-jian"

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
      "feng" => Kantele.Combat.Skills.Performs.ZileiJian.Feng,
      "luo" => Kantele.Combat.Skills.Performs.ZileiJian.Luo
    }
  end
end
