defmodule Kantele.Combat.Skills.XiaoxiangYeyu do
  @moduledoc """
  武学实装「xiaoxiang-yeyu」（源 xiaoxiang-yeyu.c，由 translate_skill.exs 生成）

  已自动化：静态招式 0 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：practice_skill
  - perform/exert 路由骨架见 tmp/perf_out/xiaoxiang_yeyu/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @actions []

  @impl true
  def id(), do: "xiaoxiang-yeyu"

  @impl true
  def valid_enable(usage), do: usage in ["tanqin-jifa"]

  @impl true
  def practice_cost(), do: %{qi: 10, neili: 0}

  # LPC `valid_learn(object me)`（源 xiaoxiang-yeyu.c）
  @impl true
  def valid_learn(stats, _character) do
    lvl = Stats.skill(stats, id())

    cond do
      Stats.skill(stats, "tanqin-jifa") < 50 ->
        {:error, "你弹琴技法水平太差，无法领会潇湘夜雨。\n"}

      Stats.skill(stats, "tanqin-jifa") < lvl ->
        {:error, "你弹琴技法水平有限，无法领会更精妙的潇湘夜雨。\n"}

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
