defmodule Kantele.Combat.Skills.XuanyuanArrow do
  @moduledoc """
  武学实装「xuanyuan-arrow」（源 xuanyuan-arrow.c，由 translate_skill.exs 生成）

  已自动化：静态招式 0 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill
  - perform/exert 路由骨架见 tmp/perf_out/xuanyuan_arrow/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @actions []

  @impl true
  def id(), do: "xuanyuan-arrow"

  @impl true
  def valid_enable(usage), do: usage in ["throwing"]

  # LPC valid_learn：throwing>=20 / throwing>=xuanyuan-arrow
  # 源第二条写的是 query_skill("xuanyuan-arror", 1)（拼写错误，永远取到 0），
  # 故 `throwing < 0` 恒假 —— 该判定在源中即死代码，此处按「不生效」保真。

  @impl true
  def practice_cost(), do: %{qi: 70, neili: 0}

  # LPC `valid_learn(object me)`（源 xuanyuan-arrow.c）
  @impl true
  def valid_learn(stats, _character) do
    cond do
      Stats.skill(stats, "throwing") < 20 ->
        {:error, "你的暗器技能不够娴熟，怎能在激战中上箭开弓射敌？\n"}

      Stats.skill(stats, "throwing") < Stats.skill(stats, "xuanyuan-arror") ->
        {:error, "你的基本暗器水平有限，难以领会更精妙的射箭之术。\n"}

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

  @impl true
  def perform_list() do
    %{
      "baibu" => Kantele.Combat.Skills.Performs.XuanyuanArrow.Baibu
    }
  end
end
