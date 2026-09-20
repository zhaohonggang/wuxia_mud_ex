defmodule Kantele.Combat.Skills.QishiJi do
  @moduledoc """
  齐氏戟法（对照 `kungfu/skill/qishi-ji.c`）

  戟/棍法载体：`valid_enable("club")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/qishi_ji/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 门槛未建模；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  @impl true
  def id(), do: "qishi-ji"

  @impl true
  def valid_enable(usage), do: usage in ["club", "parry"]

  @impl true
  def valid_learn(_stats), do: :ok

  @doc "只能学(learn)不能练"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"juan" => Kantele.Combat.Skills.Performs.QishiJi.Juan}
  end
end