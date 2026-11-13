defmodule Kantele.Combat.Skills.Hunting do
  @moduledoc """
  武学实装「hunting」（源 hunting.c，由 translate_skill.exs 生成）

  已自动化：静态招式 0 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：skill_improved, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/hunting/
  """

  use Kantele.Combat.Skill

  @actions []

  @impl true
  def id(), do: "hunting"

  # TODO(migrate) valid_enable 未识别（源可能用变量/组合判断）
  @impl true
  def valid_enable(_usage), do: false

  # LPC `valid_learn(object me)`（源 hunter.c teach_hunting()）：
  #   if (!me->query_temp("marks/hunter")) return "你我素无往来，何出此言？";
  # 端口约定：marks/hunter（持久化）即「已给猎人捕兽夹」。
  @impl true
  def valid_learn(_stats, character) do
    marks = Map.get(character.meta, :marks, %{}) || %{}

    cond do
      Map.get(marks, "hunter") in [nil, 0, false] ->
        {:error, "你我素无往来，何出此言？\n"}

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
