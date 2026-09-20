defmodule Kantele.Combat.Skills.CanghongBifa do
  @moduledoc """
  沧虹笔法（对照 `kungfu/skill/canghong-bifa.c`）

  笔/匕首法载体：`valid_enable("dagger")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/canghong_bifa/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 门槛未建模；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  @impl true
  def id(), do: "canghong-bifa"

  @impl true
  def valid_enable(usage), do: usage in ["dagger", "parry"]

  @impl true
  def valid_learn(_stats), do: :ok

  @doc "只能学(learn)不能练"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"jing" => Kantele.Combat.Skills.Performs.CanghongBifa.Jing}
  end
end