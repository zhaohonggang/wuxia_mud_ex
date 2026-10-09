defmodule Kantele.Combat.Skills.HuntianBaojian do
  @moduledoc """
  武学实装「huntian-baojian」（源 huntian-baojian.c，由 translate_skill.exs 生成）

  已自动化：静态招式 11 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：difficult_level, exert_function_file, perform_action_file, practice_skill, valid_force, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/huntian_baojian/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N施出一招",
      "force" => 481,
      "attack" => 161,
      "parry" => 114,
      "dodge" => 137,
      "damage" => 131,
      "lvl" => 0,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N错步上前，一招",
      "force" => 485,
      "attack" => 180,
      "parry" => 121,
      "dodge" => 138,
      "damage" => 137,
      "lvl" => 0,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N陡然使出",
      "force" => 451,
      "attack" => 193,
      "parry" => 113,
      "dodge" => 121,
      "damage" => 241,
      "lvl" => 0,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N一声巨喝，贯出",
      "force" => 451,
      "attack" => 193,
      "parry" => 113,
      "dodge" => 121,
      "damage" => 241,
      "lvl" => 0,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N施展",
      "force" => 261,
      "attack" => 221,
      "parry" => 209,
      "dodge" => 241,
      "damage" => 233,
      "lvl" => 0,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N陡然使出",
      "force" => 373,
      "attack" => 103,
      "parry" => 241,
      "dodge" => 261,
      "damage" => 391,
      "lvl" => 0,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N施出一招",
      "force" => 424,
      "attack" => 239,
      "parry" => 254,
      "dodge" => 272,
      "damage" => 353,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N站立不动，一声暴喝，施出",
      "force" => 484,
      "attack" => 298,
      "parry" => 254,
      "dodge" => 267,
      "damage" => 339,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N施展",
      "force" => 884,
      "attack" => 251,
      "parry" => 304,
      "dodge" => 329,
      "damage" => 358,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N陡然使出",
      "force" => 703,
      "attack" => 393,
      "parry" => 513,
      "dodge" => 321,
      "damage" => 461,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N施出一招",
      "force" => 884,
      "attack" => 398,
      "parry" => 454,
      "dodge" => 312,
      "damage" => 433,
      "lvl" => 0,
      "damage_type" => "刺伤"
    }
  ]

  @impl true
  def id(), do: "huntian-baojian"

  @impl true
  def valid_enable(usage), do: usage in ["force", "parry", "unarmed"]

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
end
