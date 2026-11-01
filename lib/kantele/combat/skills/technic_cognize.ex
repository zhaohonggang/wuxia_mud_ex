defmodule Kantele.Combat.Skills.TechnicCognize do
  @moduledoc """
  武学实装「technic-cognize」（源 technic-cognize.c，由 translate_skill.exs 生成）

  已自动化：静态招式 0 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - perform/exert 路由骨架见 tmp/perf_out/technic_cognize/
  **已迁移：**`valid_learn(stats)` 匹配 LPC `technic-cognize.c`：恒拒绝，
  文案「技能修养是你工艺技能方面的体会，无法通过简单学习获得提升。」。
  """

  use Kantele.Combat.Skill

  @actions []

  @impl true
  def id(), do: "technic-cognize"

  # TODO(migrate) valid_enable 未识别（源可能用变量/组合判断）
  @impl true
  def valid_enable(_usage), do: false

  @impl true
  def valid_learn(_stats), do: {:error, "技能修养是你工艺技能方面的体会，无法通过简单学习获得提升。\n"}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
end
