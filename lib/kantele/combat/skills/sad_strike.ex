defmodule Kantele.Combat.Skills.SadStrike do
  @moduledoc """
  武学实装「sad-strike」（源 sad-strike.c，由 translate_skill.exs 生成）

  已自动化：静态招式 17 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 1 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：hit_ob, perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/sad_strike/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N一招「",
      "force" => 250,
      "attack" => 40,
      "parry" => 0,
      "dodge" => 40,
      "damage" => 20,
      "lvl" => 0,
      "damage_type" => "内伤",
      "skill_name" => "杞人忧天"
    },
    %{
      "action" => "$N一招「",
      "force" => 260,
      "attack" => 45,
      "parry" => 0,
      "dodge" => 45,
      "damage" => 25,
      "lvl" => 10,
      "damage_type" => "瘀伤",
      "skill_name" => "无中生有"
    },
    %{
      "action" => "$N一招「",
      "force" => 280,
      "attack" => 50,
      "parry" => 0,
      "dodge" => 50,
      "damage" => 30,
      "lvl" => 20,
      "damage_type" => "内伤",
      "skill_name" => "拖泥带水"
    },
    %{
      "action" => "$N一招「",
      "force" => 300,
      "attack" => 55,
      "parry" => 0,
      "dodge" => 55,
      "damage" => 35,
      "lvl" => 40,
      "damage_type" => "瘀伤",
      "skill_name" => "力不从心"
    },
    %{
      "action" => "$N一招「",
      "force" => 330,
      "attack" => 60,
      "parry" => 0,
      "dodge" => 60,
      "damage" => 40,
      "lvl" => 60,
      "damage_type" => "瘀伤",
      "skill_name" => "行尸走肉"
    },
    %{
      "action" => "$N双掌平托，一招「",
      "force" => 360,
      "attack" => 70,
      "parry" => 0,
      "dodge" => 65,
      "damage" => 45,
      "lvl" => 80,
      "damage_type" => "瘀伤",
      "skill_name" => "庸人自扰"
    },
    %{
      "action" => "$N一招「",
      "force" => 390,
      "attack" => 80,
      "parry" => 0,
      "dodge" => 70,
      "damage" => 50,
      "lvl" => 100,
      "damage_type" => "瘀伤",
      "skill_name" => "倒行逆施"
    },
    %{
      "action" => "$N一招「",
      "force" => 420,
      "attack" => 90,
      "parry" => 0,
      "dodge" => 75,
      "damage" => 55,
      "lvl" => 120,
      "damage_type" => "内伤",
      "skill_name" => "心惊肉跳"
    },
    %{
      "action" => "$N一招「",
      "force" => 460,
      "attack" => 100,
      "parry" => 0,
      "dodge" => 80,
      "damage" => 60,
      "lvl" => 140,
      "damage_type" => "瘀伤",
      "skill_name" => "废寝忘食"
    },
    %{
      "action" => "$N一招「",
      "force" => 490,
      "attack" => 110,
      "parry" => 0,
      "dodge" => 85,
      "damage" => 65,
      "lvl" => 160,
      "damage_type" => "瘀伤",
      "skill_name" => "徘徊空谷"
    },
    %{
      "action" => "$N一招「",
      "force" => 520,
      "attack" => 125,
      "parry" => 0,
      "dodge" => 90,
      "damage" => 90,
      "lvl" => 70,
      "damage_type" => "瘀伤",
      "skill_name" => "饮恨吞声"
    },
    %{
      "action" => "$N一招「",
      "force" => 550,
      "attack" => 140,
      "parry" => 0,
      "dodge" => 95,
      "damage" => 75,
      "lvl" => 200,
      "damage_type" => "内伤",
      "skill_name" => "六神不安"
    },
    %{
      "action" => "$N一招「",
      "force" => 570,
      "attack" => 150,
      "parry" => 0,
      "dodge" => 100,
      "damage" => 80,
      "lvl" => 220,
      "damage_type" => "瘀伤",
      "skill_name" => "穷途末路"
    },
    %{
      "action" => "$N一招「",
      "force" => 590,
      "attack" => 155,
      "parry" => 0,
      "dodge" => 105,
      "damage" => 85,
      "lvl" => 240,
      "damage_type" => "内伤",
      "skill_name" => "呆若木鸡"
    },
    %{
      "action" => "$N低头冥想，一招「",
      "force" => 620,
      "attack" => 160,
      "parry" => 0,
      "dodge" => 110,
      "damage" => 90,
      "lvl" => 260,
      "damage_type" => "瘀伤",
      "skill_name" => "若有所失"
    },
    %{
      "action" => "$N一招「",
      "force" => 650,
      "attack" => 165,
      "parry" => 0,
      "dodge" => 115,
      "damage" => 95,
      "lvl" => 280,
      "damage_type" => "内伤",
      "skill_name" => "四通八达"
    },
    %{
      "action" => "$N错步上前，一招「",
      "force" => 680,
      "attack" => 170,
      "parry" => 0,
      "dodge" => 120,
      "damage" => 100,
      "lvl" => 300,
      "damage_type" => "内伤",
      "skill_name" => "鹿死谁手"
    }
  ]

  @impl true
  def id(), do: "sad-strike"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "unarmed"]

  @impl true
  def practice_cost(), do: %{qi: 150, neili: 155}

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
      "tuo" => Kantele.Combat.Skills.Performs.SadStrike.Tuo,
      "xiao" => Kantele.Combat.Skills.Performs.SadStrike.Xiao
    }
  end
end
