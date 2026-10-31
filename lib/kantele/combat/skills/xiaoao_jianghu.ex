defmodule Kantele.Combat.Skills.XiaoaoJianghu do
  @moduledoc """
  武学实装「xiaoao-jianghu」（源 xiaoao-jianghu.c，由 translate_skill.exs 生成）

  已自动化：静态招式 0 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：practice_skill
  - perform/exert 路由骨架见 tmp/perf_out/xiaoao_jianghu/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @actions []

  @impl true
  def id(), do: "xiaoao-jianghu"

  @impl true
  def valid_enable(usage), do: usage in ["chuixiao-jifa", "tanqin-jifa"]

  @impl true
  def practice_cost(), do: %{qi: 40, neili: 0}

  # LPC `valid_learn(object me)`（源 xiaoao-jianghu.c）
  @impl true
  def valid_learn(stats, _character) do
    cond do
      (Stats.skill(stats, "tanqin-jifa") < 50) and (Stats.skill(stats, "chuixiao-jifa") < 50) ->
        {:error, "你的吹萧和弹琴的技法水平都太差，还是先练好再说吧！\n"}

      (Stats.skill(stats, "tanqin-jifa") < Stats.skill(stats, "qingxin-pushan")) and (Stats.skill(stats, "cuhixiao-jifa") < Stats.skill(stats, "qingxin-pushan")) ->
        {:error, "在掌握更娴熟的吹萧技法或弹琴技法之前，你无法领会更精妙的笑傲江湖曲。\n"}

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
