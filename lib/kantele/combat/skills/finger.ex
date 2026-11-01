defmodule Kantele.Combat.Skills.Finger do
  @moduledoc """
  武学实装「finger」（源 finger.c，由 translate_skill.exs 生成）

  **已迁移**：`valid_enable(usage)` → `usage == "finger"`；`practice_cost()` = `%{qi: 50, neili: 30}`（与 LPC SKILL 默认一致）。`valid_learn` 继承基类默认 `:ok`，不 override。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：（无）
  - perform/exert 路由骨架见 tmp/perf_out/finger/
  """

  use Kantele.Combat.Skill

  @actions []

  @impl true
  def id(), do: "finger"

  @impl true
  def valid_enable(usage), do: usage == "finger"

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
