defmodule Kantele.Combat.Skills.FiveAvoid do
  @moduledoc """
  武学实装「five-avoid」（源 five-avoid.c，由 translate_skill.exs 生成）

  已自动化：静态招式 5 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/five_avoid/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "可是$n微微一笑，$N眼前水雾弥漫，$n已使出",
      "force" => 0,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 60,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "却见$n抛下手中兵刃，扑向路边的一棵大树，转眼和枝叶混为一体，",
      "force" => 0,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 70,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$n原地一转，立时钻入土中。$N这一招落到了空处，惊道",
      "force" => 0,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 80,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$n随手打出一团火球，喝道",
      "force" => 0,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 90,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$n哈哈一笑，把手中的兵刃交错一击，喝道“看我",
      "force" => 0,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 100,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    }
  ]

  @impl true
  def id(), do: "five-avoid"

  @impl true
  def valid_enable(usage), do: usage in ["dodge", "move"]

  @impl true
  def practice_cost(), do: %{qi: 65, neili: 0}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

  @impl true
  def perform_list() do
    %{
      "break" => Kantele.Combat.Skills.Performs.FiveAvoid.Break
    }
  end
end
