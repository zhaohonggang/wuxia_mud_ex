defmodule Kantele.Combat.Skills.XiantianGong do
  @moduledoc """
  武学实装「xiantian-gong」（源 xiantian-gong.c，由 translate_skill.exs 生成）

  已自动化：静态招式 4 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：difficult_level, exert_function_file, hit_ob, perform_action_file, practice_skill, valid_force, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/xiantian_gong/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N单掌一抖，运聚先天功功力，呼啸着向$n的$l处拍去",
      "force" => 430,
      "attack" => 163,
      "parry" => 81,
      "dodge" => 87,
      "damage" => 83,
      "lvl" => 0,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N右掌平伸，左掌运起先天功的劲力，猛地拍向$n的$l",
      "force" => 440,
      "attack" => 147,
      "parry" => 77,
      "dodge" => 85,
      "damage" => 81,
      "lvl" => 0,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N身形一展，右掌护住心脉，左掌中攻直进，贯向$n$l",
      "force" => 450,
      "attack" => 182,
      "parry" => 67,
      "dodge" => 75,
      "damage" => 93,
      "lvl" => 0,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N运转先天真气，双掌回圈，顿时一波澎湃的气劲直袭$n",
      "force" => 480,
      "attack" => 183,
      "parry" => 85,
      "dodge" => 87,
      "damage" => 105,
      "lvl" => 0,
      "damage_type" => "内伤"
    }
  ]

  @impl true
  def id(), do: "xiantian-gong"

  @impl true
  def valid_enable(usage), do: usage in ["force", "parry", "unarmed"]

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
end
