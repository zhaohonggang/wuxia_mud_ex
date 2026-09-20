defmodule Kantele.Combat.Skills.DuanyunFu do
  @moduledoc """
  断云拂法（对照 `kungfu/skill/duanyun-fu.c`）

  杖/棍法载体：`valid_enable("club")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/duanyun_fu/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 门槛未建模；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  @impl true
  def id(), do: "duanyun-fu"

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
    %{"tiaoyan" => Kantele.Combat.Skills.Performs.DuanyunFu.Tiaoyan}
  end
end