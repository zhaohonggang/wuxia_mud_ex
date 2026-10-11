defmodule Kantele.Combat.Skills.BiyanDao do
  @moduledoc """
  武学实装「biyan-dao」（源 biyan-dao.c，由 translate_skill.exs 生成）

  已自动化：静态招式 5 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/biyan_dao/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N藏刀内收，一招「碧海青天」，刀锋自下而上划了个半弧，向$n的$l挥去",
      "force" => 10,
      "attack" => 18,
      "parry" => 5,
      "dodge" => 1,
      "damage" => 10,
      "lvl" => 0,
      "damage_type" => "割伤",
      "skill_name" => "碧海青天"
    },
    %{
      "action" => "$N左掌虚托右肘，一招「碧玉丹心」，手中$w笔直划向$n的$l",
      "force" => 30,
      "attack" => 16,
      "parry" => 7,
      "dodge" => 3,
      "damage" => 12,
      "lvl" => 20,
      "damage_type" => "割伤",
      "skill_name" => "碧玉丹心"
    },
    %{
      "action" => "$N一招「青烟缈缈」，$w绕颈而过，刷地一声自上而下向$n猛劈",
      "force" => 53,
      "attack" => 19,
      "parry" => 13,
      "dodge" => 2,
      "damage" => 17,
      "lvl" => 40,
      "damage_type" => "割伤",
      "skill_name" => "青烟缈缈"
    },
    %{
      "action" => "$N右手反执刀柄，一招「烟碧三宵」，猛一挫身，$w直向$n的颈中斩去",
      "force" => 61,
      "attack" => 27,
      "parry" => 19,
      "dodge" => 5,
      "damage" => 25,
      "lvl" => 60,
      "damage_type" => "割伤",
      "skill_name" => "烟碧三宵"
    },
    %{
      "action" => "$N一招「烟消云散」，无数刀尖化作点点繁星，向$n的$l挑去",
      "force" => 80,
      "attack" => 52,
      "parry" => 11,
      "dodge" => 10,
      "damage" => 30,
      "lvl" => 80,
      "damage_type" => "割伤",
      "skill_name" => "烟消云散"
    }
  ]

  @impl true
  def id(), do: "biyan-dao"

  @impl true
  def valid_enable(usage), do: usage in ["blade", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 35, neili: 20}

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
      "luo" => Kantele.Combat.Skills.Performs.BiyanDao.Luo
    }
  end
end
