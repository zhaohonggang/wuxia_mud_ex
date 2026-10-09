defmodule Kantele.Combat.Skills.XiangmoChu do
  @moduledoc """
  武学实装「xiangmo-chu」（源 xiangmo-chu.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/xiangmo_chu/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N高举起手中$w，使出一招「金刚在世」，直直劈向$n的$l处",
      "force" => 100,
      "attack" => 0,
      "parry" => 20,
      "dodge" => -5,
      "damage" => 30,
      "lvl" => 0,
      "damage_type" => "挫伤",
      "skill_name" => "金刚在世"
    },
    %{
      "action" => "$N使出「金刚伏魔」，单手舞动$w，一伏身，$w横扫$n的下盘",
      "force" => 130,
      "attack" => 5,
      "parry" => 25,
      "dodge" => 5,
      "damage" => 40,
      "lvl" => 40,
      "damage_type" => "挫伤",
      "skill_name" => "金刚伏魔"
    },
    %{
      "action" => "$N反身仰面，使出一式「金刚宣法」，双手握$w，直刺$n的$l",
      "force" => 150,
      "attack" => 8,
      "parry" => 25,
      "dodge" => 10,
      "damage" => 45,
      "lvl" => 80,
      "damage_type" => "挫伤",
      "skill_name" => "金刚宣法"
    },
    %{
      "action" => "$N使出一招「引趣众生」，双手高高举起$w，猛撩向$n的裆部",
      "force" => 160,
      "attack" => 15,
      "parry" => 31,
      "dodge" => 0,
      "damage" => 50,
      "lvl" => 100,
      "damage_type" => "挫伤",
      "skill_name" => "引趣众生"
    },
    %{
      "action" => "$N舞动手中$w，使一式「歌舞阎罗」，锤影顿时罩住$n的全身",
      "force" => 190,
      "attack" => 22,
      "parry" => 35,
      "dodge" => 10,
      "damage" => 55,
      "lvl" => 120,
      "damage_type" => "挫伤",
      "skill_name" => "歌舞阎罗"
    },
    %{
      "action" => "$N使出一招「浮游血海」，全身贴地而飞，手中$w直捣$n的$l",
      "force" => 230,
      "attack" => 28,
      "parry" => 38,
      "dodge" => 15,
      "damage" => 60,
      "lvl" => 130,
      "damage_type" => "挫伤",
      "skill_name" => "浮游血海"
    },
    %{
      "action" => "$N使出一式「驱鬼御魔」，以手中$w支地，双足飞揣$n的$l处",
      "force" => 260,
      "attack" => 33,
      "parry" => 32,
      "dodge" => 20,
      "damage" => 70,
      "lvl" => 140,
      "damage_type" => "挫伤",
      "skill_name" => "驱鬼御魔"
    },
    %{
      "action" => "$N运力于掌，使出「荡魔除妖」飞身疾进，手中$w横扫$n的$l",
      "force" => 300,
      "attack" => 35,
      "parry" => 33,
      "dodge" => 20,
      "damage" => 80,
      "lvl" => 150,
      "damage_type" => "挫伤",
      "skill_name" => "荡魔除妖"
    }
  ]

  @impl true
  def id(), do: "xiangmo-chu"

  @impl true
  def valid_enable(usage), do: usage in ["hammer", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 45, neili: 60}

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
