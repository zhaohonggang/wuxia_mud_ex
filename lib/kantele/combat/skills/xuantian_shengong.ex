defmodule Kantele.Combat.Skills.XuantianShengong do
  @moduledoc """
  武学实装「xuantian-shengong」（源 xuantian-shengong.c，由 translate_skill.exs 生成）

  已自动化：静态招式 0 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：exert_function_file, practice_skill
  - perform/exert 路由骨架见 tmp/perf_out/xuantian_shengong/
  **已迁移：**`valid_learn/2(stats, character)` 匹配 LPC `xuantian-shengong.c` 两门门槛：
  `force>=120`、`gender==无性 && 本门>49`（性别门需 arity-2，force 门回落 `valid_learn/1`）。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats
  alias Kantele.Combat.Skill

  @actions []

  @impl true
  def id(), do: "xuantian-shengong"

  @impl true
  def valid_enable(usage), do: usage in ["force"]

  defp gender_of(%{meta: %{env: %{gender: gender}}}) when is_binary(gender), do: gender
  defp gender_of(_), do: nil

  # LPC valid_learn：force>=120 / 无性 且 xuantian-shengong>49。
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())

    cond do
      gender_of(character) == "无性" and lvl > 49 ->
        {:error, "你无根无性，阴阳不调，难以领会高深的玄天神功。\n"}

      true ->
        valid_learn(stats)
    end
  end

  @impl true
  def valid_learn(stats) do
    force = Stats.skill(stats, "force")

    cond do
      force < 120 ->
        {:error, "你的基本内功火候还不够。\n"}

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
