defmodule Kantele.Combat.Skills.ShaolinJiuyang do
  @moduledoc """
  武学实装「shaolin-jiuyang」（源 shaolin-jiuyang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 2 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：exert_function_file, practice_skill, valid_force, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/shaolin_jiuyang/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N飞身一跃而起，身法陡然加快，朝着$n$l快速攻出数十拳",
      "force" => 0,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 0,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N沉身运气，一拳击向$n，刹那间，$N全身竟浮现出一道金光",
      "force" => 0,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 0,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    }
  ]

  @impl true
  def id(), do: "shaolin-jiuyang"

  @impl true
  def valid_enable(usage), do: usage in ["force"]

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
end
