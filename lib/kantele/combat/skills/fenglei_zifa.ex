defmodule Kantele.Combat.Skills.FengleiZifa do
  @moduledoc """
  风雷子法（对照 `kungfu/skill/fenglei-zifa.c`）

  暗器载体：`valid_enable("throwing")`；
  `valid_force` 接受 基本暗器/风雷子法 共存。

  绝招实现见 `lib/kantele/combat/skills/performs/fenglei_zifa/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的 max_neili/force/throwing 门槛未实现（`valid_learn` 恒 :ok）。
  - LPC `practice_skill` 训练（qi 35 / neili 48 消耗）未建模（`practice_cost` 返回 nil）。
  """

  use Kantele.Combat.Skill

  @impl true
  def id(), do: "fenglei-zifa"

  @impl true
  def valid_enable(usage), do: usage == "throwing"

  @impl true
  def valid_force(force), do: force in ["basic-throwing", "fenglei-zifa"]

  @impl true
  def valid_learn(_stats), do: :ok

  @doc "只能学(learn)不能练（LPC practice_skill 返回失败）"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"she" => Kantele.Combat.Skills.Performs.FengleiZifa.She}
  end
end