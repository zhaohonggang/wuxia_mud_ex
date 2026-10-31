defmodule Kantele.Combat.Skills.Buddhism do
  @moduledoc """
  武学实装「buddhism」（源 buddhism.c，由 translate_skill.exs 生成）

  已自动化：静态招式 0 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：practice_skill
  - perform/exert 路由骨架见 tmp/perf_out/buddhism/
  """

  use Kantele.Combat.Skill

  @actions []

  @impl true
  def id(), do: "buddhism"

  # TODO(migrate) valid_enable 未识别（源可能用变量/组合判断）
  @impl true
  def valid_enable(_usage), do: false

  # LPC `valid_learn(object me)`（源 buddhism.c）
  @impl true
  def valid_learn(_stats, character) do
    guilty = guilty_of(character)

    cond do
      guilty > 0 ->
        {:error, "你屡犯僧家数戒，尘俗之心太重，无法修炼禅宗心法。\n"}

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

  # LPC `me->query("guilty")`：僧家戒律违犯计数。本端口未建模 → 恒 0。
  defp guilty_of(%{meta: meta}) when is_map(meta) do
    case Map.get(meta, :guilty) do
      n when is_integer(n) -> n
      _ -> 0
    end
  end

  defp guilty_of(_character), do: 0
end
