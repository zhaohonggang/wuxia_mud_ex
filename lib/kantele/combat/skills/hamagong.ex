defmodule Kantele.Combat.Skills.Hamagong do
  @moduledoc """
  武学实装「hamagong」（源 hamagong.c，由 translate_skill.exs 生成）

  已自动化：静态招式 4 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：difficult_level, exert_function_file, hit_ob, perform_action_file, practice_skill, valid_force, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/hamagong/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N忽而倒竖，一手撑住地面，身子横挺，另一掌向$n的胸口拍去",
      "force" => 310,
      "attack" => 103,
      "parry" => 21,
      "dodge" => 35,
      "damage" => 58,
      "lvl" => 0,
      "damage_type" => "震伤"
    },
    %{
      "action" => "$N双腿微曲，右掌平伸，左掌运起蛤蟆功劲力，呼的一声推向$n",
      "force" => 332,
      "attack" => 112,
      "parry" => 37,
      "dodge" => 50,
      "damage" => 61,
      "lvl" => 180,
      "damage_type" => "震伤"
    },
    %{
      "action" => "$N闭眼逼住呼吸，猛跃而起，眼睛也不及睁开，便向$n推了出去",
      "force" => 360,
      "attack" => 122,
      "parry" => 53,
      "dodge" => 67,
      "damage" => 72,
      "lvl" => 220,
      "damage_type" => "震伤"
    },
    %{
      "action" => "$N脚步摇幌，忽然双腿一登，口中阁的一声叫喝，向$n猛然推出",
      "force" => 410,
      "attack" => 143,
      "parry" => 67,
      "dodge" => 75,
      "damage" => 81,
      "lvl" => 240,
      "damage_type" => "震伤"
    }
  ]

  @impl true
  def id(), do: "hamagong"

  @impl true
  def valid_enable(usage), do: usage in ["force", "parry", "strike"]

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
end
