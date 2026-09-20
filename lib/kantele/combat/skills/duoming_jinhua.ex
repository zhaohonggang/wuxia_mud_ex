defmodule Kantele.Combat.Skills.DuomingJinhua do
  @moduledoc """
  夺命金花（对照 `kungfu/skill/duoming-jinhua.c`）

  暗器/金花载体：`valid_enable("throwing")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/duoming_jinhua/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 门槛未建模；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  @impl true
  def id(), do: "duoming-jinhua"

  @impl true
  def valid_enable(usage), do: usage in ["throwing", "parry"]

  @impl true
  def valid_learn(_stats), do: :ok

  @doc "只能学(learn)不能练"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"hua" => Kantele.Combat.Skills.Performs.DuomingJinhua.Hua}
  end
end