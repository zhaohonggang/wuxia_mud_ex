defmodule Kantele.Combat.Skills.HenshanJian do
  @moduledoc """
  衡山剑法（对照 `kungfu/skill/henshan-jian.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/henshan_jian/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 门槛未建模（force>=80）；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  @impl true
  def id(), do: "henshan-jian"

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
    %{"huan" => Kantele.Combat.Skills.Performs.HenshanJian.Huan}
  end
end