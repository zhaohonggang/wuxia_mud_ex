defmodule Kantele.Combat.Skills.QimenWuxing do
  @moduledoc """
  奇门五行（对照 `kungfu/skill/qimen-wuxing.c`）

  知识类（`type() == "knowledge"`）：无招式表、不可 enable 到任何用法。

  已按 LPC 迁移（2026-10-31）：

    - `valid_learn/2`：`mathematics < 200` 拒绝；`mathematics < qimen-wuxing`
      拒绝（算术须不弱于本门）。
    - `practice_cost/0` 返回 `nil`（LPC `practice_skill` 直接 `notify_fail`，
      只能靠学）。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @actions []

  @impl true
  def id(), do: "qimen-wuxing"

  # 源无 valid_enable —— LPC 调用未定义函数即失败，故任何用法均不可 enable。
  @impl true
  def valid_enable(_usage), do: false

  @doc "只能学(learn)不能练（LPC practice_skill 返回 notify_fail）"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def valid_learn(stats, _character) do
    mathematics = Stats.skill(stats, "mathematics")

    cond do
      mathematics < 200 ->
        {:error, "你的算术知识太差，无法理解奇门五行的奥妙。\n"}

      mathematics < Stats.skill(stats, id()) ->
        {:error, "你的算术知识有限，无法理解更深奥的奇门五行。\n"}

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
