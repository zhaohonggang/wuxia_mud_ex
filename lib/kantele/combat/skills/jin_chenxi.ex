defmodule Kantele.Combat.Skills.JinChenxi do
  @moduledoc """
  武学实装「jin-chenxi」（源 jin-chenxi.c，由 translate_skill.exs 生成）

  已自动化：静态招式 3 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：exert_function_file, perform_action_file, practice_skill, valid_force, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/jin_chenxi/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N施展",
      "force" => 284,
      "attack" => 51,
      "parry" => 4,
      "dodge" => -29,
      "damage" => 58,
      "lvl" => 0,
      "damage_type" => "抓伤"
    },
    %{
      "action" => "$N陡然使出",
      "force" => 303,
      "attack" => 93,
      "parry" => 13,
      "dodge" => -21,
      "damage" => 161,
      "lvl" => 150,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N施出一招",
      "force" => 384,
      "attack" => 98,
      "parry" => 54,
      "dodge" => -12,
      "damage" => 233,
      "lvl" => 200,
      "damage_type" => "刺伤"
    }
  ]

  @impl true
  def id(), do: "jin-chenxi"

  @impl true
  def valid_enable(usage), do: usage in ["force", "parry", "unarmed"]

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
end
