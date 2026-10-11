defmodule Kantele.Combat.Skills.ZijinbaguaDao do
  @moduledoc """
  武学实装「zijinbagua-dao」（源 zijinbagua-dao.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/zijinbagua_dao/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N脚踏八卦方位，手中$w横推，由上至下向$n砍去",
      "force" => 145,
      "attack" => 35,
      "parry" => 12,
      "dodge" => 30,
      "damage" => 32,
      "lvl" => 0,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N刀锋自下而上划了个半弧，$w一提一收，平刃挥向$n的颈部",
      "force" => 173,
      "attack" => 42,
      "parry" => 15,
      "dodge" => 40,
      "damage" => 38,
      "lvl" => 30,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N脚踏八卦方位，斜步上前，将$w舞得如白雾一般压向$n",
      "force" => 198,
      "attack" => 51,
      "parry" => 17,
      "dodge" => 45,
      "damage" => 44,
      "lvl" => 50,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N转“嵌”位至“易”位，$w缓缓的斜着向$n推去",
      "force" => 237,
      "attack" => 55,
      "parry" => 21,
      "dodge" => 55,
      "damage" => 50,
      "lvl" => 80,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N手拖$w，转身跃起，一道白光射向$n的胸口",
      "force" => 261,
      "attack" => 55,
      "parry" => 32,
      "dodge" => 27,
      "damage" => 65,
      "lvl" => 100,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N挥舞$w，上劈下撩，左挡右开，齐齐罩向$n",
      "force" => 287,
      "attack" => 70,
      "parry" => 35,
      "dodge" => 30,
      "damage" => 70,
      "lvl" => 120,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N左脚跃步落地，$w顺势往前，挟风声劈向$n的$l",
      "force" => 360,
      "attack" => 80,
      "parry" => 35,
      "dodge" => 45,
      "damage" => 86,
      "lvl" => 140,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N蓦的使一招「八卦八阵」，顿时剑光中无数朵刀花从四面八方涌向$n全身",
      "force" => 410,
      "attack" => 95,
      "parry" => 32,
      "dodge" => 64,
      "damage" => 89,
      "lvl" => 160,
      "damage_type" => "割伤"
    }
  ]

  @impl true
  def id(), do: "zijinbagua-dao"

  @impl true
  def valid_enable(usage), do: usage in ["blade", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 85, neili: 100}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

  @impl true
  def perform_list() do
    %{
      "bagua" => Kantele.Combat.Skills.Performs.ZijinbaguaDao.Bagua
    }
  end
end
