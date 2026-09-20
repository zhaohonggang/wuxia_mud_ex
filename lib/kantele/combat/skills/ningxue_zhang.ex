defmodule Kantele.Combat.Skills.NingxueZhang do
  @moduledoc """
  凝血掌法（对照 `kungfu/skill/ningxue-zhang.c`）

  掌/杖法载体：`valid_enable("strike")` / `valid_enable("parry")` / `valid_enable("staff")`。

  绝招实现见 `lib/kantele/combat/skills/performs/ningxue_zhang/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 门槛未建模；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  @impl true
  def id(), do: "ningxue-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["strike", "parry", "staff"]

  @impl true
  def valid_learn(_stats), do: :ok

  @doc "只能学(learn)不能练"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"xue" => Kantele.Combat.Skills.Performs.NingxueZhang.Xue}
  end
end