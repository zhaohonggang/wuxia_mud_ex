defmodule Kantele.Combat.Skills.ShenlongBashi do
  @moduledoc """
  武学实装「shenlong-bashi」（源 shenlong-bashi.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/shenlong_bashi/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N使一招「疏影横斜」，左手轻轻一抹，向$n的$l拍去",
      "force" => 100,
      "attack" => 0,
      "parry" => 10,
      "dodge" => 0,
      "damage" => 20,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "疏影横斜"
    },
    %{
      "action" => "$N鼓气大喝，双掌使一招「五丁开山」，推向$n的$l",
      "force" => 150,
      "attack" => 5,
      "parry" => 30,
      "dodge" => 0,
      "damage" => 30,
      "lvl" => 60,
      "damage_type" => "瘀伤",
      "skill_name" => "五丁开山"
    },
    %{
      "action" => "$N顺势使一招「风行草偃」，移肩转身，左掌护面，右掌直击$n",
      "force" => 200,
      "attack" => 15,
      "parry" => 20,
      "dodge" => 80,
      "damage" => 40,
      "lvl" => 80,
      "damage_type" => "瘀伤",
      "skill_name" => "风行草偃"
    },
    %{
      "action" => "$N退后几步，突然反手一掌，一招「神龙摆尾」，无比怪异地击向$n",
      "force" => 250,
      "attack" => 21,
      "parry" => 20,
      "dodge" => 80,
      "damage" => 50,
      "lvl" => 100,
      "damage_type" => "瘀伤",
      "skill_name" => "神龙摆尾"
    },
    %{
      "action" => "$N使一式「风卷残云」，全身飞速旋转，双掌一前一后，猛地拍向$n的胸口",
      "force" => 300,
      "attack" => 32,
      "parry" => 52,
      "dodge" => 10,
      "damage" => 50,
      "lvl" => 140,
      "damage_type" => "瘀伤",
      "skill_name" => "风卷残云"
    },
    %{
      "action" => "$N忽的使出「乾坤倒旋」，以手支地，双腿翻飞踢向$n",
      "force" => 350,
      "attack" => 35,
      "parry" => 32,
      "dodge" => 60,
      "damage" => 60,
      "lvl" => 160,
      "damage_type" => "瘀伤",
      "skill_name" => "乾坤倒旋"
    },
    %{
      "action" => "$N大吼一声，使出「同归于尽」，不顾一切般扑向$n",
      "force" => 380,
      "attack" => 45,
      "parry" => 30,
      "dodge" => 45,
      "damage" => 60,
      "lvl" => 180,
      "damage_type" => "内伤",
      "skill_name" => "同归于尽"
    },
    %{
      "action" => "$N深吸一口气，身体涨成球状，猛然流星赶月般直撞向$n",
      "force" => 400,
      "attack" => 52,
      "parry" => 15,
      "dodge" => 80,
      "damage" => 70,
      "lvl" => 200,
      "damage_type" => "内伤",
      "skill_name" => "流星赶月"
    }
  ]

  @impl true
  def id(), do: "shenlong-bashi"

  @impl true
  def valid_enable(usage), do: usage in ["hand", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 61, neili: 62}

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
      "xian" => Kantele.Combat.Skills.Performs.ShenlongBashi.Xian
    }
  end
end
