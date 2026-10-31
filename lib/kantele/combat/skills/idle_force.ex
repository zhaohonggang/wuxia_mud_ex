defmodule Kantele.Combat.Skills.IdleForce do
  @moduledoc """
  武学实装「idle-force」（源 idle-force.c，由 translate_skill.exs 生成）

  已自动化：静态招式 0 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：skill_improved, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/idle_force/
  """

  use Kantele.Combat.Skill

  @actions []

  @impl true
  def id(), do: "idle-force"

  # 源无 valid_enable —— LPC 调用未定义函数即失败，故任何用法均不可 enable。
  @impl true
  def valid_enable(_usage), do: false

  @doc "源无 practice_skill（LPC 调用即失败），故不可练"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
end
