defmodule Kantele.Combat.Skills.JuemenGun do
  @moduledoc """
  武学实装「juemen-gun」（源 juemen-gun.c，由 translate_skill.exs 生成）

  已自动化：静态招式 5 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/juemen_gun/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N斜里冲前一步，身法诡异，手中$w横扫$n的$l",
      "force" => 220,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 50,
      "damage" => 40,
      "lvl" => 0,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N忽然直身飞入半空，很久也不见人影，$n正搜寻间，$N已",
      "force" => 210,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 55,
      "damage" => 45,
      "lvl" => 0,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N原地一个后滚翻，却在落地的一刹那，身体向$n平飞过",
      "force" => 210,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 60,
      "damage" => 35,
      "lvl" => 0,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N突然一个急转身，$w横扫一圈后挟着猛烈的劲道打向$n的$l",
      "force" => 200,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 65,
      "damage" => 45,
      "lvl" => 0,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N向前扑出，顺势一滚，接着翻身跳起，手里$w斜向上击向$n的$l",
      "force" => 220,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 55,
      "damage" => 30,
      "lvl" => 0,
      "damage_type" => "挫伤"
    }
  ]

  @impl true
  def id(), do: "juemen-gun"

  @impl true
  def valid_enable(usage), do: usage in ["dodge", "parry", "staff"]

  @impl true
  def practice_cost(), do: %{qi: 45, neili: 38}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
end
