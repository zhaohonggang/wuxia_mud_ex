defmodule Kantele.Combat.Skills.JingzhongBafa do
  @moduledoc """
  武学实装「jingzhong-bafa」（源 jingzhong-bafa.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/jingzhong_bafa/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N横立不动，手中$w横推，一招「不攻」，由上至下向$nl慢慢推去",
      "force" => 232,
      "attack" => 157,
      "parry" => 221,
      "dodge" => 123,
      "damage" => 389,
      "lvl" => 0,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N一招「沙鸥掠波」，刀锋自下而上划了个半弧，$w一提一收，平刃挥向$n的颈部",
      "force" => 285,
      "attack" => 183,
      "parry" => 221,
      "dodge" => 123,
      "damage" => 421,
      "lvl" => 0,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N使出一招「天设牢笼」，将$w舞得如白雾一般压向$n",
      "force" => 297,
      "attack" => 179,
      "parry" => 221,
      "dodge" => 123,
      "damage" => 435,
      "lvl" => 0,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N一招「闭门铁扇」，$w缓缓的斜着向$n推去",
      "force" => 334,
      "attack" => 191,
      "parry" => 221,
      "dodge" => 123,
      "damage" => 451,
      "lvl" => 0,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N手拖$w，转身跃起，一招「翼德闯帐」，一道白光射向$n的胸口",
      "force" => 382,
      "attack" => 207,
      "parry" => 211,
      "dodge" => 121,
      "damage" => 479,
      "lvl" => 0,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N挥舞$w，使出一招「白鹤舒翅」，上劈下撩，左挡右开，齐齐罩向$n",
      "force" => 397,
      "attack" => 223,
      "parry" => 221,
      "dodge" => 123,
      "damage" => 483,
      "lvl" => 0,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N一招「春风送暖」，左脚跃步落地，$w顺势往前，挟风声劈向$n的$l",
      "force" => 421,
      "attack" => 257,
      "parry" => 213,
      "dodge" => 133,
      "damage" => 534,
      "lvl" => 0,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N蓦的使一招「八方藏刀」，顿时剑光中无数朵刀花从四面八方涌向$n全身",
      "force" => 423,
      "attack" => 271,
      "parry" => 221,
      "dodge" => 173,
      "damage" => 589,
      "lvl" => 0,
      "damage_type" => "割伤"
    }
  ]

  @impl true
  def id(), do: "jingzhong-bafa"

  @impl true
  def valid_enable(usage), do: usage in ["blade", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 300, neili: 300}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
end
