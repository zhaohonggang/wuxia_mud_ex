defmodule Kantele.Combat.Skills.YechaGun do
  @moduledoc """
  武学实装「yecha-gun」（源 yecha-gun.c，由 translate_skill.exs 生成）

  已自动化：静态招式 6 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/yecha_gun/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N棍势连绵，着着俱是进攻招式，手中$w一连几棍，劈头盖脸地朝着$n砸下",
      "force" => 89,
      "attack" => 33,
      "parry" => 35,
      "dodge" => 30,
      "damage" => 34,
      "lvl" => 0,
      "damage_type" => "砸伤"
    },
    %{
      "action" => "$N点、扎、缠、扫、棍风呼呼，攻势极为凌厉，舞起一团棍影齐齐罩向$n",
      "force" => 116,
      "attack" => 33,
      "parry" => 44,
      "dodge" => 35,
      "damage" => 52,
      "lvl" => 30,
      "damage_type" => "砸伤"
    },
    %{
      "action" => "$N哈哈大笑，单手提棍，手中$w闪电般的直袭而出，砸向$n$l",
      "force" => 136,
      "attack" => 48,
      "parry" => 40,
      "dodge" => 48,
      "damage" => 78,
      "lvl" => 60,
      "damage_type" => "砸伤"
    },
    %{
      "action" => "$N大喝一声，手中$w高高举起，挂着风声劈头盖脸的砸向$n的$l",
      "force" => 200,
      "attack" => 58,
      "parry" => 22,
      "dodge" => 40,
      "damage" => 100,
      "lvl" => 90,
      "damage_type" => "砸伤"
    },
    %{
      "action" => "$N扑身上前，手中$w骤然加紧，刹那间幻起十几条棍影，漫天飞舞，左右缭绕攻到$n的$l",
      "force" => 234,
      "attack" => 66,
      "parry" => 31,
      "dodge" => 36,
      "damage" => 101,
      "lvl" => 120,
      "damage_type" => "砸伤"
    },
    %{
      "action" => "$N纵身跃起，手中$w转得如车轮一般，一棒化数棒直击$n顶门",
      "force" => 273,
      "attack" => 80,
      "parry" => 35,
      "dodge" => 35,
      "damage" => 104,
      "lvl" => 150,
      "damage_type" => "砸伤"
    }
  ]

  @impl true
  def id(), do: "yecha-gun"

  @impl true
  def valid_enable(usage), do: usage in ["club", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 55, neili: 45}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

  @impl true
  def perform_list() do
    %{
      "hongxia" => Kantele.Combat.Skills.Performs.YechaGun.Hongxia
    }
  end
end
