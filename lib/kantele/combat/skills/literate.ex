defmodule Kantele.Combat.Skills.Literate do
  @moduledoc """
  武学实装「literate」（源 literate.c，由 translate_skill.exs 生成）

  **已迁移**：`valid_enable(_usage) -> false`（知识类，按 batch4 结论保真）；`practice_cost()` = `%{qi: 50, neili: 30}`。`valid_learn` 继承基类默认 `:ok`（LPC `return 1`），不 override。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：skill_improved, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/literate/
  """

  use Kantele.Combat.Skill

  @actions []

  @impl true
  def id(), do: "literate"

  # TODO(migrate) valid_enable 未识别（源可能用变量/组合判断）
  @impl true
  def valid_enable(_usage), do: false

  @doc "练习消耗：默认 qi 50 / neili 30"
  @impl true
  def practice_cost(), do: %{qi: 50, neili: 30}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
end
