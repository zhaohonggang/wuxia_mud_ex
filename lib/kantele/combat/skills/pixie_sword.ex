defmodule Kantele.Combat.Skills.PixieSword do
  @moduledoc """
  武学实装「pixie-sword」（源 pixie-sword.c，由 translate_skill.exs 生成）

  已自动化：静态招式 6 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/pixie_sword/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N使一招「群邪辟易」，手中$w圈起，倏地刺出，银星点点，剑尖直向$n的$l刺去",
      "force" => 0,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 5,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "群邪辟易"
    },
    %{
      "action" => "$N一招「钟馗抉目」，剑随身转，围着$n身围疾刺，剑光霍霍罩向$n的$l",
      "force" => 0,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 0,
      "damage" => 5,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "钟馗抉目"
    },
    %{
      "action" => "$N舞动$w，一招「花开见佛」挟著无数剑光刺向$n的$l",
      "force" => 0,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 10,
      "damage" => 10,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "花开见佛"
    },
    %{
      "action" => "$N手中$w一声清啸，祭出「流星赶月」剑锋闪烁不定，银光飞舞，猛地里一剑挺出，直刺$n$l",
      "force" => 0,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 5,
      "damage" => 5,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "流星赶月"
    },
    %{
      "action" => "$N手中$w剑光暴长，一招「飞燕穿柳」往$n$l刺去",
      "force" => 0,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 10,
      "damage" => 10,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "飞燕穿柳"
    },
    %{
      "action" => "$N手中$w化成一道光弧，直指$n$l，一招「江上弄笛」发出虎哮龙吟刺去",
      "force" => 0,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 5,
      "damage" => 15,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "江上弄笛"
    }
  ]

  @impl true
  def id(), do: "pixie-sword"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "sword"]

  @impl true
  def practice_cost(), do: %{qi: 25, neili: 2}

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
