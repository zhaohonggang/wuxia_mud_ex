defmodule Kantele.Combat.Skills.ShenxingBaibian do
  @moduledoc """
  神行百变（对照 `kungfu/skill/shenxing-baibian.c`）

  轻功载体：`valid_enable("dodge")` / `valid_enable("move")`。

  绝招实现见 `lib/kantele/combat/skills/performs/shenxing_baibian/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 无门槛（return 1），本版同样放行；
  - LPC 招式表与 `practice_skill` 未建模（`query_action` 返回空、
    `practice_cost` 为 nil）。
  """

  use Kantele.Combat.Skill

  @impl true
  def id(), do: "shenxing-baibian"

  @impl true
  def valid_enable(usage), do: usage in ["dodge", "move"]

  @impl true
  def valid_learn(_stats), do: :ok

  @doc "只能学(learn)不能练（LPC practice_skill 未建模）"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"piao" => Kantele.Combat.Skills.Performs.ShenxingBaibian.Piao}
  end
end