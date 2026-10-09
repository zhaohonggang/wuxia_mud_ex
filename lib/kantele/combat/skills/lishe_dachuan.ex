defmodule Kantele.Combat.Skills.LisheDachuan do
  @moduledoc """
  武学实装「lishe-dachuan」（源 lishe-dachuan.c，由 translate_skill.exs 生成）

  已自动化：静态招式 1 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/lishe_dachuan/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N施出一招「利涉大川」，右掌插腰，左掌劈向$n的$l",
      "force" => 230,
      "attack" => 0,
      "parry" => 15,
      "dodge" => -10,
      "damage" => 70,
      "lvl" => 0,
      "damage_type" => "震伤"
    }
  ]

  @impl true
  def id(), do: "lishe-dachuan"

  @impl true
  def valid_enable(usage), do: usage in ["strike"]

  @impl true
  def practice_cost(), do: %{qi: 100, neili: 40}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
end
