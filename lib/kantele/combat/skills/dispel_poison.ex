defmodule Kantele.Combat.Skills.DispelPoison do
  @moduledoc """
  武学实装「dispel-poison」（源 dispel-poison.c，由 translate_skill.exs 生成）

  已自动化：静态招式 0 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：practice_skill
  - perform/exert 路由骨架见 tmp/perf_out/dispel_poison/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @actions []

  @impl true
  def id(), do: "dispel-poison"

  @impl true
  def valid_enable(usage), do: usage in ["medical", "poison"]

  # LPC `valid_learn(object me)`（源 dispel-poison.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      Stats.skill(stats, "force") < 80 ->
        {:error, "你的内功火候不够，无法学习妙手驱毒。\n"}

      not is_nil(max_neili) and max_neili < 350 ->
        {:error, "你的内力太弱，无法学习妙手驱毒。\n"}

      (Stats.skill(stats, "poison") < lvl) and (Stats.skill(stats, "medical") < lvl + 20) ->
        {:error, "你的基本毒技和基本医术都水平有限，无法领会更高深的妙手驱毒。\n"}

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

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil
end
