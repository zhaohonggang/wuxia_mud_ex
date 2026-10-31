defmodule Kantele.Combat.Skills.TangmenPoison do
  @moduledoc """
  武学实装「tangmen-poison」（源 tangmen-poison.c，由 translate_skill.exs 生成）

  已自动化：静态招式 0 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/tangmen_poison/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @actions []

  @impl true
  def id(), do: "tangmen-poison"

  @impl true
  def valid_enable(usage), do: usage in ["poison"]

  # LPC `valid_learn(object me)`（源 tangmen-poison.c）
  @impl true
  def valid_learn(stats, _character) do
    lvl = Stats.skill(stats, id())

    cond do
      Stats.skill(stats, "poison") < 100 ->
        {:error, "你的基本毒技造诣太浅，无法领会深奥的唐门奇毒。\n"}

      Stats.skill(stats, "poison") < lvl ->
        {:error, "你的基本毒技水平有限，无法掌握更深奥的唐门奇毒。\n"}

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
