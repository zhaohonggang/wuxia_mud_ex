defmodule Kantele.Combat.Skills.JinwuDaofa do
  @moduledoc """
  武学实装「jinwu-daofa」（源 jinwu-daofa.c，由 translate_skill.exs 生成）

  已自动化：静态招式 10 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/jinwu_daofa/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N藏刀内收，一招「开门楫盗」，刀锋自下而上划了个半弧，向$n的$l挥去",
      "force" => 20,
      "attack" => 28,
      "parry" => 5,
      "dodge" => 1,
      "damage" => 10,
      "lvl" => 0,
      "damage_type" => "割伤",
      "skill_name" => "开门楫盗"
    },
    %{
      "action" => "$N左掌虚托右肘，一招「梅雪逢夏」，手中$w笔直划向$n的$l",
      "force" => 30,
      "attack" => 36,
      "parry" => 10,
      "dodge" => 3,
      "damage" => 15,
      "lvl" => 20,
      "damage_type" => "割伤",
      "skill_name" => "梅雪逢夏"
    },
    %{
      "action" => "$N一招「千钧压驼」，$w绕颈而过，刷地一声自上而下向$n猛劈",
      "force" => 40,
      "attack" => 43,
      "parry" => 13,
      "dodge" => 2,
      "damage" => 20,
      "lvl" => 40,
      "damage_type" => "割伤",
      "skill_name" => "千钧压驼"
    },
    %{
      "action" => "$N右手反执刀柄，一招「赤日金鼓」，猛一挫身，$w直向$n的颈中斩去",
      "force" => 60,
      "attack" => 47,
      "parry" => 19,
      "dodge" => 5,
      "damage" => 25,
      "lvl" => 60,
      "damage_type" => "割伤",
      "skill_name" => "赤日金鼓"
    },
    %{
      "action" => "$N一招「汉将当关」，无数刀尖化作点点繁星，向$n的$l挑去",
      "force" => 80,
      "attack" => 52,
      "parry" => 11,
      "dodge" => 10,
      "damage" => 30,
      "lvl" => 80,
      "damage_type" => "割伤",
      "skill_name" => "汉将当关"
    },
    %{
      "action" => "$N双手合执$w，一招「鲍鱼之肆」，拧身急转，刀尖直刺向$n的双眼",
      "force" => 110,
      "attack" => 59,
      "parry" => 15,
      "dodge" => 15,
      "damage" => 35,
      "lvl" => 100,
      "damage_type" => "割伤",
      "skill_name" => "鲍鱼之肆"
    },
    %{
      "action" => "$N一招「旁敲侧击」，手中$w划出一个大平十字，向$n纵横劈去",
      "force" => 140,
      "attack" => 63,
      "parry" => 15,
      "dodge" => 15,
      "damage" => 40,
      "lvl" => 120,
      "damage_type" => "割伤",
      "skill_name" => "旁敲侧击"
    },
    %{
      "action" => "$N反转刀尖对准自己，一招「长者折枝」，全身一个翻滚，$w向$n拦腰斩去",
      "force" => 180,
      "attack" => 71,
      "parry" => 10,
      "dodge" => 20,
      "damage" => 50,
      "lvl" => 140,
      "damage_type" => "割伤",
      "skill_name" => "长者折枝"
    },
    %{
      "action" => "$N一招「赤日炎炎」，$w的刀光仿佛化成一簇簇烈焰，将$n团团围绕",
      "force" => 220,
      "attack" => 78,
      "parry" => 20,
      "dodge" => 10,
      "damage" => 55,
      "lvl" => 160,
      "damage_type" => "割伤",
      "skill_name" => "赤日炎炎"
    },
    %{
      "action" => "$N刀尖平指，一招「大海沉沙」，一片片切骨刀气如飓风般裹向$n的全身",
      "force" => 270,
      "attack" => 85,
      "parry" => 25,
      "dodge" => 5,
      "damage" => 60,
      "lvl" => 180,
      "damage_type" => "割伤",
      "skill_name" => "大海沉沙"
    }
  ]

  @impl true
  def id(), do: "jinwu-daofa"

  @impl true
  def valid_enable(usage), do: usage in ["blade", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 65, neili: 70}

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
      "chi" => Kantele.Combat.Skills.Performs.JinwuDaofa.Chi
    }
  end
end
