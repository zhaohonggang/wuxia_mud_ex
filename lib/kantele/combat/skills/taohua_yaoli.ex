defmodule Kantele.Combat.Skills.TaohuaYaoli do
  @moduledoc """
  武学实装「taohua-yaoli」（源 taohua-yaoli.c，由 translate_skill.exs 生成）

  已自动化：静态招式 0 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/taohua_yaoli/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @actions []

  @impl true
  def id(), do: "taohua-yaoli"

  @impl true
  def valid_enable(usage), do: usage in ["medical"]

  # LPC `valid_learn(object me)`（源 taohua-yaoli.c）
  @impl true
  def valid_learn(stats, _character) do
    lvl = Stats.skill(stats, id())

    cond do
      Stats.skill(stats, "medical") < 100 ->
        {:error, "你的基本医术造诣太浅，无法领会深奥的桃花药理。\n"}

      Stats.skill(stats, "medical") < lvl ->
        {:error, "你的基本医术水平有限，无法掌握更深奥的桃花药理。\n"}

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
