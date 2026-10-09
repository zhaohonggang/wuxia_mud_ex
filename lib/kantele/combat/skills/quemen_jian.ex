defmodule Kantele.Combat.Skills.QuemenJian do
  @moduledoc """
  武学实装「quemen-jian」（源 quemen-jian.c，由 translate_skill.exs 生成）

  已自动化：静态招式 4 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/quemen_jian/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N纵身跃起手中$w轻挥，一招「残」字诀，斩向$n后颈",
      "force" => 80,
      "attack" => 35,
      "parry" => 10,
      "dodge" => 30,
      "damage" => 75,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "残字诀"
    },
    %{
      "action" => "$N手中$w连话三个弧形，一招「破」字诀，向$n的右臂齐肩斩落",
      "force" => 100,
      "attack" => 45,
      "parry" => 22,
      "dodge" => 45,
      "damage" => 88,
      "lvl" => 30,
      "damage_type" => "刺伤",
      "skill_name" => "破字诀"
    },
    %{
      "action" => "$N轻吁一声，飞身一跃而起，一招「戮」字诀，连续向$n刺出数剑",
      "force" => 120,
      "attack" => 51,
      "parry" => 18,
      "dodge" => 53,
      "damage" => 95,
      "lvl" => 60,
      "damage_type" => "刺伤",
      "skill_name" => "戮字诀"
    },
    %{
      "action" => "$N仰天一声清啸，斜行向前，一招「缺」字诀，$w横削直击，击向$n的$l",
      "force" => 150,
      "attack" => 58,
      "parry" => 20,
      "dodge" => 52,
      "damage" => 110,
      "lvl" => 90,
      "damage_type" => "割伤",
      "skill_name" => "缺字诀"
    }
  ]

  @impl true
  def id(), do: "quemen-jian"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "sword"]

  @impl true
  def practice_cost(), do: %{qi: 60, neili: 16}

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
