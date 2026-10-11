defmodule Kantele.Combat.Skills.TianshanZhang do
  @moduledoc """
  武学实装「tianshan-zhang」（源 tianshan-zhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 10 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/tianshan_zhang/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N使出一招「冰河开冻」，手中$w大开大阖扫向$n的$l",
      "force" => 110,
      "attack" => 0,
      "parry" => 0,
      "dodge" => -3,
      "damage" => 5,
      "lvl" => 0,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N手中$w阵阵风响，一招「山风凛冽」向$n的$l攻去",
      "force" => 110,
      "attack" => 0,
      "parry" => 0,
      "dodge" => -5,
      "damage" => 10,
      "lvl" => 13,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N举起$w，居高临下使一招「天山雪崩」砸向$n的$l",
      "force" => 120,
      "attack" => 0,
      "parry" => 0,
      "dodge" => -10,
      "damage" => 20,
      "lvl" => 30,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N一招「残阳照雪」，纵身飘开数尺，手中$w砸向$n的$l",
      "force" => 130,
      "attack" => 0,
      "parry" => 0,
      "dodge" => -30,
      "damage" => 20,
      "lvl" => 45,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N使一招「回光幻电」，手中$w幻一条疾光点向$n的$l",
      "force" => 140,
      "attack" => 0,
      "parry" => 0,
      "dodge" => -20,
      "damage" => 30,
      "lvl" => 60,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N使出的「风霜碎影」，$w连挥杖影霍霍劈向$n的$l",
      "force" => 140,
      "attack" => 0,
      "parry" => 0,
      "dodge" => -20,
      "damage" => 30,
      "lvl" => 75,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N的$w凭空一指，一招「断石狼烟」点向$n的$l",
      "force" => 150,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 20,
      "damage" => 40,
      "lvl" => 90,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N纵身一跃，手中$w一招「长空雷隐」对准$n的$l扫去",
      "force" => 160,
      "attack" => 0,
      "parry" => 0,
      "dodge" => -40,
      "damage" => 50,
      "lvl" => 105,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N手中$w中宫直进，一式「冰谷初虹」对准$n的$l点去",
      "force" => 180,
      "attack" => 0,
      "parry" => 0,
      "dodge" => -40,
      "damage" => 60,
      "lvl" => 120,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N一招「峰回路转」，$w左右迂回向$n的$l点去",
      "force" => 210,
      "attack" => 0,
      "parry" => 0,
      "dodge" => -5,
      "damage" => 80,
      "lvl" => 145,
      "damage_type" => "挫伤"
    }
  ]

  @impl true
  def id(), do: "tianshan-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "staff"]

  @impl true
  def practice_cost(), do: %{qi: 42, neili: 26}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

  @impl true
  def perform_list() do
    %{
      "fugu" => Kantele.Combat.Skills.Performs.TianshanZhang.Fugu,
      "xue" => Kantele.Combat.Skills.Performs.TianshanZhang.Xue
    }
  end
end
