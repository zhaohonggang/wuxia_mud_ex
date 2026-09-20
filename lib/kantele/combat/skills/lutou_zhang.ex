defmodule Kantele.Combat.Skills.LutouZhang do
  @moduledoc """
  鹿头杖法（对照 `kungfu/skill/lutou-zhang.c`）

  杖法载体：`valid_enable("staff")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/lutou_zhang/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 门槛未建模；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  @impl true
  def id(), do: "lutou-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["staff", "parry"]

  @impl true
  def valid_learn(_stats), do: :ok

  @doc "只能学(learn)不能练"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"tong" => Kantele.Combat.Skills.Performs.LutouZhang.Tong}
  end
end