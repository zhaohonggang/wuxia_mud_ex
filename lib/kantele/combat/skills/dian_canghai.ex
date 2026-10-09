defmodule Kantele.Combat.Skills.DianCanghai do
  @moduledoc """
  武学实装「dian-canghai」（源 dian-canghai.c，由 translate_skill.exs 生成）

  已自动化：静态招式 4 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：exert_function_file, perform_action_file, practice_skill, valid_force, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/dian_canghai/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N施出一招",
      "force" => 381,
      "attack" => 61,
      "parry" => 14,
      "dodge" => -37,
      "damage" => 31,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N错步上前，一招",
      "force" => 485,
      "attack" => 80,
      "parry" => 21,
      "dodge" => -38,
      "damage" => 137,
      "lvl" => 150,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N陡然使出",
      "force" => 451,
      "attack" => 93,
      "parry" => 13,
      "dodge" => -21,
      "damage" => 141,
      "lvl" => 150,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N一声巨喝，贯出",
      "force" => 451,
      "attack" => 93,
      "parry" => 13,
      "dodge" => -21,
      "damage" => 141,
      "lvl" => 200,
      "damage_type" => "割伤"
    }
  ]

  @impl true
  def id(), do: "dian-canghai"

  @impl true
  def valid_enable(usage), do: usage in ["force", "parry", "unarmed"]

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
end
