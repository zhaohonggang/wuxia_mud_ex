defmodule Kantele.Combat.Skills.Russian do
  @moduledoc """
  武学实装「russian」（源 russian.c，由 translate_skill.exs 生成）

  已自动化：静态招式 0 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：skill_improved
  - perform/exert 路由骨架见 tmp/perf_out/russian/
  **已迁移：**`valid_learn(stats)` 匹配 LPC `russian.c` 两门门槛：
  `literate>=100`、`literate>=本门`。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @actions []

  @impl true
  def id(), do: "russian"

  # TODO(migrate) valid_enable 未识别（源可能用变量/组合判断）
  @impl true
  def valid_enable(_usage), do: false

  @impl true
  def valid_learn(stats) do
    lvl = Stats.skill(stats, id())
    literate = Stats.skill(stats, "literate")

    cond do
      literate < 100 ->
        {:error, "你连读书写字都没学好，怎么学习俄文？\n"}

      literate < lvl ->
        {:error, "你的读书写字水平有限，无法掌握更深奥的俄文。\n"}

      true ->
        :ok
    end
  end

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
end
