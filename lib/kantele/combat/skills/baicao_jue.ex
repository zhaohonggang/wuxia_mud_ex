defmodule Kantele.Combat.Skills.BaicaoJue do
  @moduledoc """
  武学实装「baicao-jue」（源 baicao-jue.c，由 translate_skill.exs 生成）

  已自动化：静态招式 0 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：practice_skill
  - perform/exert 路由骨架见 tmp/perf_out/baicao_jue/
  **已迁移：**`valid_learn(stats)` 匹配 LPC `baicao-jue.c` 四门门槛：
  `medical>=150`、`yaowang-miaoshu>=150`、`medical>=本门`、`yaowang-miaoshu>=本门`。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @actions []

  @impl true
  def id(), do: "baicao-jue"

  @impl true
  def valid_enable(usage), do: usage in ["medical"]

  @impl true
  def valid_learn(stats) do
    lvl = Stats.skill(stats, id())
    medical = Stats.skill(stats, "medical")
    miaoshu = Stats.skill(stats, "yaowang-miaoshu")

    cond do
      medical < 150 ->
        {:error, "你的基本医术造诣太浅，无法领会深奥的百草诀。\n"}

      miaoshu < 150 ->
        {:error, "你的药王妙术造诣太浅，无法领会深奥的百草诀。\n"}

      medical < lvl ->
        {:error, "你的基本医术水平有限，无法掌握更深奥的百草诀。\n"}

      miaoshu < lvl ->
        {:error, "你的药王妙术水平有限，无法掌握更深奥的百草诀。\n"}

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
