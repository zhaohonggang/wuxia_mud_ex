defmodule Kantele.Combat.Skills.JianlongZaitian do
  @moduledoc """
  武学实装「jianlong-zaitian」（源 jianlong-zaitian.c，由 translate_skill.exs 生成）

  已自动化：静态招式 1 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/jianlong_zaitian/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N右掌一招「见龙在田」，迅捷无比地劈向$n的$l",
      "force" => 260,
      "attack" => 0,
      "parry" => 20,
      "dodge" => 20,
      "damage" => 50,
      "lvl" => 0,
      "damage_type" => "震伤"
    }
  ]

  @impl true
  def id(), do: "jianlong-zaitian"

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
