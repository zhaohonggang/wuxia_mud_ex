defmodule Kantele.Combat.Skills.DouzhuanXingyi do
  @moduledoc """
  武学实装「douzhuan-xingyi」（源 douzhuan-xingyi.c，由 translate_skill.exs 生成）

  已自动化：静态招式 0 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_damage, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/douzhuan_xingyi/
  """

  use Kantele.Combat.Skill

  @actions []

  @impl true
  def id(), do: "douzhuan-xingyi"

  @impl true
  def valid_enable(usage), do: usage in ["parry"]

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

  @impl true
  def perform_list() do
    %{
      "yi" => Kantele.Combat.Skills.Performs.DouzhuanXingyi.Yi
    }
  end
end
