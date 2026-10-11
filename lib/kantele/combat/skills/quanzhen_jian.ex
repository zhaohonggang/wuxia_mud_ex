defmodule Kantele.Combat.Skills.QuanzhenJian do
  @moduledoc """
  全真剑法（对照 `kungfu/skill/quanzhen-jian.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/quanzhen_jian/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 门槛未建模；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  @impl true
  def id(), do: "quanzhen-jian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "parry"]

  @impl true
  def valid_learn(_stats), do: :ok

  @doc "只能学(learn)不能练"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{
      "chan" => Kantele.Combat.Skills.Performs.QuanzhenJian.Chan,
      "ding" => Kantele.Combat.Skills.Performs.QuanzhenJian.Ding,
      "hua" => Kantele.Combat.Skills.Performs.QuanzhenJian.Hua,
      "lian" => Kantele.Combat.Skills.Performs.QuanzhenJian.Lian
    }
  end
end