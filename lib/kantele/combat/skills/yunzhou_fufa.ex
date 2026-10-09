defmodule Kantele.Combat.Skills.YunzhouFufa do
  @moduledoc """
  武学实装「yunzhou-fufa」（源 yunzhou-fufa.c，由 translate_skill.exs 生成）

  已自动化：静态招式 5 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/yunzhou_fufa/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N右手微抬，一招「长空万里」，手中$w笔直刺向$n",
      "force" => 45,
      "attack" => 0,
      "parry" => 12,
      "dodge" => 35,
      "damage" => 15,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N身形一转，手中$w如矫龙般腾空一卷，猛地向$n劈头打下",
      "force" => 80,
      "attack" => 0,
      "parry" => 15,
      "dodge" => 28,
      "damage" => 30,
      "lvl" => 30,
      "damage_type" => "抽伤"
    },
    %{
      "action" => "$N一声长啸，手中$w挥舞得呼呼作响，如长龙般地袭向$n全身",
      "force" => 116,
      "attack" => 0,
      "parry" => 29,
      "dodge" => 43,
      "damage" => 51,
      "lvl" => 50,
      "damage_type" => "抽伤"
    },
    %{
      "action" => "$N身法忽变，忽左忽右，手中$w龙吟不定只向$n$l",
      "force" => 180,
      "attack" => 0,
      "parry" => 33,
      "dodge" => 55,
      "damage" => 60,
      "lvl" => 80,
      "damage_type" => "抽伤"
    },
    %{
      "action" => "$N飞身一跃而起，$w宛如游龙，破空而下，攻向$n",
      "force" => 210,
      "attack" => 0,
      "parry" => 36,
      "dodge" => 65,
      "damage" => 80,
      "lvl" => 110,
      "damage_type" => "抽伤"
    }
  ]

  @impl true
  def id(), do: "yunzhou-fufa"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "whip"]

  @impl true
  def practice_cost(), do: %{qi: 35, neili: 40}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
end
