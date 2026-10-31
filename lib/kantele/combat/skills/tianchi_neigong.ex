defmodule Kantele.Combat.Skills.TianchiNeigong do
  @moduledoc """
  武学实装「tianchi-neigong」（源 tianchi-neigong.c，由 translate_skill.exs 生成）

  已自动化：静态招式 0 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：exert_function_file, practice_skill, valid_force, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/tianchi_neigong/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @actions []

  @impl true
  def id(), do: "tianchi-neigong"

  @impl true
  def valid_enable(usage), do: usage in ["force"]

  @impl true
  def valid_force(force), do: force in ["zhanshen-xinjing", "honghua-xinfa"]

  @doc "只能学(learn)不能练（LPC practice_skill 返回失败）"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    force = Stats.skill(stats, "force")

    cond do
      force < 60 ->
        {:error, "你的基本内功火候还不够。\n"}

      gender_of(character) == "无性" and lvl > 49 ->
        {:error, "你无根无性，阴阳不调，难以领会高深的天池内功。\n"}

      true ->
        :ok
    end
  end

  defp gender_of(%{meta: %{env: %{gender: gender}}}) when is_binary(gender), do: gender
  defp gender_of(_), do: "男性"

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
end
