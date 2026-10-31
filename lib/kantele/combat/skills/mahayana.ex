defmodule Kantele.Combat.Skills.Mahayana do
  @moduledoc """
  武学实装「mahayana」（源 mahayana.c，由 translate_skill.exs 生成）

  已自动化：静态招式 0 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：skill_improved
  - perform/exert 路由骨架见 tmp/perf_out/mahayana/
  """

  use Kantele.Combat.Skill

  @actions []

  @impl true
  def id(), do: "mahayana"

  # TODO(migrate) valid_enable 未识别（源可能用变量/组合判断）
  @impl true
  def valid_enable(_usage), do: false

  # LPC `valid_learn(object me)`（源 mahayana.c）
  @impl true
  def valid_learn(_stats, character) do
    shen = shen_of(character)

    cond do
      shen < 0 ->
        {:error, "你的邪气太重，无法修炼大乘涅磐功。\n"}

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

  # LPC `me->query("shen")`：正邪值
  defp shen_of(%{meta: %{stats: %{shen: n}}}) when is_integer(n), do: n
  defp shen_of(_character), do: 0
end
