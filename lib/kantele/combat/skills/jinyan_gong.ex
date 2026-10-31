defmodule Kantele.Combat.Skills.JinyanGong do
  @moduledoc """
  武学实装「jinyan-gong」（源 jinyan-gong.c，由 translate_skill.exs 生成）

  已自动化：静态招式 0 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：practice_skill, query_effect_dodge
  - perform/exert 路由骨架见 tmp/perf_out/jinyan_gong/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @actions []

  @impl true
  def id(), do: "jinyan-gong"

  @impl true
  def valid_enable(usage), do: usage in ["dodge", "move"]

  @impl true
  def practice_cost(), do: %{qi: 58, neili: 55}

  # LPC `valid_learn(object me)`（源 jinyan-gong.c）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      Stats.skill(stats, "dodge") < 50 ->
        {:error, "你基本轻功修为有限，难以修炼金雁功。\n"}

      not is_nil(max_neili) and max_neili < 500 ->
        {:error, "你内力修为太浅，难以修炼金雁功。\n"}

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
