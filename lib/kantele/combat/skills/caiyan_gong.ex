defmodule Kantele.Combat.Skills.CaiyanGong do
  @moduledoc """
  彩云功（对照 `kungfu/skill/caiyan-gong.c`）

  棍/杖法载体：`valid_enable("club")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/caiyan_gong/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 门槛未建模；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  @impl true
  def id(), do: "caiyan-gong"

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
    %{"huan" => Kantele.Combat.Skills.Performs.CaiyanGong.Huan}
  end
end