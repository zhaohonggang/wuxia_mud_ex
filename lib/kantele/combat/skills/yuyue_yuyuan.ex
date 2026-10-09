defmodule Kantele.Combat.Skills.YuyueYuyuan do
  @moduledoc """
  武学实装「yuyue-yuyuan」（源 yuyue-yuyuan.c，由 translate_skill.exs 生成）

  已自动化：静态招式 1 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/yuyue_yuyuan/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N使出「鱼跃于渊」，身形飞起，双掌并在一起向$n的$l劈下",
      "force" => 240,
      "attack" => 0,
      "parry" => -5,
      "dodge" => 10,
      "damage" => 60,
      "lvl" => 0,
      "damage_type" => "震伤"
    }
  ]

  @impl true
  def id(), do: "yuyue-yuyuan"

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
