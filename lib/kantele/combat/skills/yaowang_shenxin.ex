defmodule Kantele.Combat.Skills.YaowangShenxin do
  @moduledoc """
  武学实装「yaowang-shenxin」（源 yaowang-shenxin.c，由 translate_skill.exs 生成）

  已自动化：静态招式 0 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/yaowang_shenxin/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @actions []

  @impl true
  def id(), do: "yaowang-shenxin"

  @impl true
  def valid_enable(usage), do: usage in ["poison"]

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  @doc """
  学习门槛（对照 `yaowang-shenxin.c` valid_learn）

  poison>=150 / dispel-poison>=150 / poison>=本门 / dispel-poison>=本门。
  LPC 以 `return 1` 收尾（无 `::valid_learn` 回落）。
  """
  @impl true
  def valid_learn(stats) do
    cond do
      Stats.skill(stats, "poison") < 150 ->
        {:error, "你的基本毒技造诣太浅，无法领会深奥的药王神辛。\n"}

      Stats.skill(stats, "dispel-poison") < 150 ->
        {:error, "你的妙手驱毒造诣太浅，无法领会深奥的药王神辛。\n"}

      Stats.skill(stats, "poison") < Stats.skill(stats, id()) ->
        {:error, "你的基本毒技水平有限，无法掌握更深奥的药王神辛。\n"}

      Stats.skill(stats, "dispel-poison") < Stats.skill(stats, id()) ->
        {:error, "你的妙手驱毒水平有限，无法掌握更深奥的药王神辛。\n"}

      true ->
        :ok
    end
  end

  def actions(), do: @actions
end
