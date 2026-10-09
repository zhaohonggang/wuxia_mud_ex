defmodule Kantele.Combat.Skills.HuashanSword do
  @moduledoc """
  武学实装「huashan-sword」（源 huashan-sword.c，由 translate_skill.exs 生成）

  已自动化：静态招式 6 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_effect, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/huashan_sword/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N使一招「有凤来仪」，手中$w剑光暴长，向$n的$l刺去",
      "force" => 70,
      "attack" => 10,
      "parry" => 5,
      "dodge" => 10,
      "damage" => 30,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "有凤来仪"
    },
    %{
      "action" => "$N剑随身转，一招「无边落木」罩向$n的$l",
      "force" => 120,
      "attack" => 20,
      "parry" => 15,
      "dodge" => 20,
      "damage" => 40,
      "lvl" => 20,
      "damage_type" => "刺伤",
      "skill_name" => "无边落木"
    },
    %{
      "action" => "$N舞动$w，一招「鸿飞冥冥」挟著无数剑光刺向$n的$l",
      "force" => 160,
      "attack" => 25,
      "parry" => 20,
      "dodge" => 30,
      "damage" => 45,
      "lvl" => 40,
      "damage_type" => "刺伤",
      "skill_name" => "鸿飞冥冥"
    },
    %{
      "action" => "$N手中$w龙吟一声，祭出「平沙落雁」往$n的$l刺出数剑",
      "force" => 190,
      "attack" => 30,
      "parry" => 28,
      "dodge" => 35,
      "damage" => 50,
      "lvl" => 60,
      "damage_type" => "刺伤",
      "skill_name" => "平沙落雁"
    },
    %{
      "action" => "$N手中$w剑光暴长，一招「金玉满堂」往$n$l刺去",
      "force" => 220,
      "attack" => 40,
      "parry" => 33,
      "dodge" => 40,
      "damage" => 55,
      "lvl" => 80,
      "damage_type" => "刺伤",
      "skill_name" => "金玉满堂"
    },
    %{
      "action" => "$N手中$w化成一道光弧，直指$n$l，一招「白虹贯日」发出虎哮龙吟刺去",
      "force" => 260,
      "attack" => 50,
      "parry" => 40,
      "dodge" => -20,
      "damage" => 90,
      "lvl" => 100,
      "damage_type" => "刺伤",
      "skill_name" => "白虹贯日"
    }
  ]

  @impl true
  def id(), do: "huashan-sword"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "sword"]

  @impl true
  def practice_cost(), do: %{qi: 50, neili: 31}

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
