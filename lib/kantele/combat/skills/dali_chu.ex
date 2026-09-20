defmodule Kantele.Combat.Skills.DaliChu do
  @moduledoc """
  大力锄法（对照 `kungfu/skill/dali-chu.c`）

  锄/锤法载体：`valid_enable("hammer")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/dali_chu/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 门槛未建模；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  @impl true
  def id(), do: "dali-chu"

  @impl true
  def valid_enable(usage), do: usage in ["hammer", "parry"]

  @impl true
  def valid_learn(_stats), do: :ok

  @doc "只能学(learn)不能练"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"hong" => Kantele.Combat.Skills.Performs.DaliChu.Hong}
  end
end