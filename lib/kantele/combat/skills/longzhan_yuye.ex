defmodule Kantele.Combat.Skills.LongzhanYuye do
  @moduledoc """
  武学实装「longzhan-yuye」（源 longzhan-yuye.c，由 translate_skill.exs 生成）

  已自动化：静态招式 1 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/longzhan_yuye/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N脚下一转，突然欺到$n身前，一招「龙战于野」拍向$n的$l",
      "force" => 240,
      "attack" => 0,
      "parry" => -10,
      "dodge" => 40,
      "damage" => 110,
      "lvl" => 0,
      "damage_type" => "震伤"
    }
  ]

  @impl true
  def id(), do: "longzhan-yuye"

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
