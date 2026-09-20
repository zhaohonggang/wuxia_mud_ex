defmodule Kantele.Combat.Skills.DaojianGuizhen do
  @moduledoc """
  刀剑归真（对照 `kungfu/skill/daojian-guizhen.c`）

  刀剑双修载体：`valid_enable("blade")` / `valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/daojian_guizhen/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 门槛未建模；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  @impl true
  def id(), do: "daojian-guizhen"

  @impl true
  def valid_enable(usage), do: usage in ["blade", "sword", "parry"]

  @impl true
  def valid_learn(_stats), do: :ok

  @doc "只能学(learn)不能练"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"daojian" => Kantele.Combat.Skills.Performs.DaojianGuizhen.Daojian}
  end
end