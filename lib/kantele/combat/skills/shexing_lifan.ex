defmodule Kantele.Combat.Skills.ShexingLifan do
  @moduledoc """
  武学实装「shexing-lifan」（源 shexing-lifan.c，由 translate_skill.exs 生成）

  已自动化：静态招式 1 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_damage, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/shexing_lifan/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N身行忽而随意转动，如同水蛇一般，忽而飞身跃起，在半空中一个翻滚，招式怪异之极",
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
  def id(), do: "shexing-lifan"

  @impl true
  def valid_enable(usage), do: usage in ["dodge", "move"]

  @impl true
  def practice_cost(), do: %{qi: 80, neili: 120}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
end
