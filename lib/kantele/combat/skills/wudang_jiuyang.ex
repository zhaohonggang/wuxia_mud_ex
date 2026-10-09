defmodule Kantele.Combat.Skills.WudangJiuyang do
  @moduledoc """
  武学实装「wudang-jiuyang」（源 wudang-jiuyang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 2 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：exert_function_file, practice_skill, valid_force, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/wudang_jiuyang/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N急运武当九阳神功，猛的一拳在呼啸声中陡然挥击而出",
      "force" => 0,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 0,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N一声暴喝，十指暮的张开，一股雄厚的内劲澎湃而出",
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
  def id(), do: "wudang-jiuyang"

  @impl true
  def valid_enable(usage), do: usage in ["force"]

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
end
