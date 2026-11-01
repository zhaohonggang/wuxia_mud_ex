defmodule Kantele.Combat.Skills.XuwenQixingding do
  @moduledoc """
  武学实装「xuwen-qixingding」（源 xuwen-qixingding.c，由 translate_skill.exs 生成）

  已自动化：静态招式 0 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill
  - perform/exert 路由骨架见 tmp/perf_out/xuwen_qixingding/
  **已迁移：**`valid_learn(stats)` 匹配 LPC `xuwen-qixingding.c` 两门门槛：
  `throwing>=20`、`throwing>=本门`。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @actions []

  @impl true
  def id(), do: "xuwen-qixingding"

  @impl true
  def valid_enable(usage), do: usage in ["throwing"]

  @impl true
  def valid_learn(stats) do
    lvl = Stats.skill(stats, id())
    throwing = Stats.skill(stats, "throwing")

    cond do
      throwing < 20 ->
        {:error, "你的暗器技能不够娴熟。\n"}

      throwing < lvl ->
        {:error, "你的基本暗器水平有限，难以领会更精妙的虚蚊七星钉。\n"}

      true ->
        :ok
    end
  end

  @impl true
  def practice_cost(), do: %{qi: 100, neili: 0}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
end
