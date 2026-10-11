defmodule Kantele.Combat.Skills.TianluoDiwang do
  @moduledoc """
  武学实装「tianluo-diwang」（源 tianluo-diwang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 6 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, query_effect_parry, valid_combine, valid_damage, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/tianluo_diwang/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N左掌划一半圆，右掌划出另一半圆，呈合拢之势，疾拍$n的胸前大穴",
      "force" => 160,
      "attack" => 10,
      "parry" => 10,
      "dodge" => 10,
      "damage" => 10,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N左掌护胸，右拳凝劲后发，深吸一口气，缓缓推向$n的$l",
      "force" => 195,
      "attack" => 20,
      "parry" => 25,
      "dodge" => 15,
      "damage" => 15,
      "lvl" => 30,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N纵身向前扑去，一下急冲疾缩，就在两臂将合未合之际，双手抱向$n的$l",
      "force" => 230,
      "attack" => 30,
      "parry" => 30,
      "dodge" => 20,
      "damage" => 32,
      "lvl" => 60,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N两掌上下护胸，掌势突然一变，骤然化为满天掌雨，攻向$n",
      "force" => 260,
      "attack" => 40,
      "parry" => 40,
      "dodge" => 20,
      "damage" => 40,
      "lvl" => 90,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N长袖挥处，两股袖风扑出，$n只觉得密不透风，周身都是掌印，怎么也闪躲不开",
      "force" => 270,
      "attack" => 50,
      "parry" => 55,
      "dodge" => 35,
      "damage" => 65,
      "lvl" => 120,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N双臂飞舞，两只手掌宛似化成了千手千掌，任$n如何跃腾闪躲，始终飞不出",
      "force" => 300,
      "attack" => 65,
      "parry" => 70,
      "dodge" => 40,
      "damage" => 80,
      "lvl" => 150,
      "damage_type" => "瘀伤"
    }
  ]

  @impl true
  def id(), do: "tianluo-diwang"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "strike"]

  @impl true
  def practice_cost(), do: %{qi: 50, neili: 35}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

  @impl true
  def perform_list() do
    %{
      "wang" => Kantele.Combat.Skills.Performs.TianluoDiwang.Wang
    }
  end
end
