defmodule Kantele.Combat.Skills.QiulinShiye do
  @moduledoc """
  秋林师业（对照 `kungfu/skill/qiulin-shiye.c`）

  空手/轻功载体：`valid_enable("unarmed")` / `valid_enable("dodge")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/qiulin_shiye/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 门槛未建模；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  @impl true
  def id(), do: "qiulin-shiye"

  @impl true
  def valid_enable(usage), do: usage in ["unarmed", "dodge", "parry"]

  @impl true
  def valid_learn(_stats), do: :ok

  @doc "只能学(learn)不能练"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"wu" => Kantele.Combat.Skills.Performs.QiulinShiye.Wu}
  end
end