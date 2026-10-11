defmodule Kantele.Combat.Skills.TianzhuJian do
  @moduledoc """
  武学实装「tianzhu-jian」（源 tianzhu-jian.c，由 translate_skill.exs 生成）

  已自动化：静态招式 5 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/tianzhu_jian/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N飞身跃起，挺剑刺向$n$l，正是一招「天山人间」",
      "force" => 45,
      "attack" => 10,
      "parry" => 20,
      "dodge" => 18,
      "damage" => 20,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "天山人间"
    },
    %{
      "action" => "$N气运于剑，陡然直进，一招「一柱擎天」已然使出，$w直指$n$l",
      "force" => 90,
      "attack" => 24,
      "parry" => 40,
      "dodge" => 25,
      "damage" => 35,
      "lvl" => 25,
      "damage_type" => "刺伤",
      "skill_name" => "一柱擎天"
    },
    %{
      "action" => "$N剑势突变，飘忽不定，一式「云里雾里」，向$n$l刺去",
      "force" => 110,
      "attack" => 30,
      "parry" => 40,
      "dodge" => 30,
      "damage" => 40,
      "lvl" => 50,
      "damage_type" => "刺伤",
      "skill_name" => "云里雾里"
    },
    %{
      "action" => "$N轻啸一声，$w一抖，一式「气冠长虹」，眨眼间$w已到$n$l",
      "force" => 120,
      "attack" => 35,
      "parry" => 45,
      "dodge" => 45,
      "damage" => 48,
      "lvl" => 75,
      "damage_type" => "刺伤",
      "skill_name" => "气冠长虹"
    },
    %{
      "action" => "$N踏前半步，手中$w如影如幻，竟向$n$l刺去，正是一招「天柱云气」",
      "force" => 160,
      "attack" => 55,
      "parry" => 60,
      "dodge" => 80,
      "damage" => 60,
      "lvl" => 100,
      "damage_type" => "刺伤",
      "skill_name" => "天柱云气"
    }
  ]

  @impl true
  def id(), do: "tianzhu-jian"

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
      "suo" => Kantele.Combat.Skills.Performs.TianzhuJian.Suo
    }
  end
end
