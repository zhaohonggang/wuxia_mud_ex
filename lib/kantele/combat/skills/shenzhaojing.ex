defmodule Kantele.Combat.Skills.Shenzhaojing do
  @moduledoc """
  武学实装「shenzhaojing」（源 shenzhaojing.c，由 translate_skill.exs 生成）

  已自动化：静态招式 4 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：difficult_level, exert_function_file, hit_ob, perform_action_file, practice_skill, valid_force, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/shenzhaojing/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N倏然跃近，击出一拳，这一拳无声无影，去势快极，向$n的胸口打去",
      "force" => 323,
      "attack" => 119,
      "parry" => 94,
      "dodge" => 81,
      "damage" => 68,
      "lvl" => 0,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N丝毫不动声色，右掌平伸，左掌运起神照经神功的劲力，呼的一声拍向$n",
      "force" => 362,
      "attack" => 138,
      "parry" => 51,
      "dodge" => 73,
      "damage" => 73,
      "lvl" => 200,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N身形微微一展，已然游走至$n跟前，陡然间双掌齐施，向$n猛拍而去",
      "force" => 389,
      "attack" => 152,
      "parry" => 53,
      "dodge" => 78,
      "damage" => 87,
      "lvl" => 220,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N退后一步，双掌回收，凌空划出一个圆圈，顿时一股澎湃的气劲直涌$n而出",
      "force" => 410,
      "attack" => 163,
      "parry" => 67,
      "dodge" => 75,
      "damage" => 93,
      "lvl" => 250,
      "damage_type" => "内伤"
    }
  ]

  @impl true
  def id(), do: "shenzhaojing"

  @impl true
  def valid_enable(usage), do: usage in ["force", "parry", "unarmed"]

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

  @impl true
  def perform_list() do
    %{
      "wu" => Kantele.Combat.Skills.Performs.Shenzhaojing.Wu,
      "ying" => Kantele.Combat.Skills.Performs.Shenzhaojing.Ying
    }
  end

  @impl true
  def exert_list() do
    %{
      "powerup" => Kantele.Combat.Skills.Performs.Shenzhaojing.Powerup,
      "shield" => Kantele.Combat.Skills.Performs.Shenzhaojing.Shield
    }
  end
end
