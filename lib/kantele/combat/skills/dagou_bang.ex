defmodule Kantele.Combat.Skills.DagouBang do
  @moduledoc """
  打狗棒法（对照 `kungfu/skill/dagou-bang.c`）

  棒法载体：`valid_enable("staff")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/dagou_bang/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 门槛未建模；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  @impl true
  def id(), do: "dagou-bang"

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
    %{
      "chan" => Kantele.Combat.Skills.Performs.DagouBang.Chan,
      "feng" => Kantele.Combat.Skills.Performs.DagouBang.Feng,
      "tian" => Kantele.Combat.Skills.Performs.DagouBang.Tian,
      "ban" => Kantele.Combat.Skills.Performs.DagouBang.Ban,
      "chuo" => Kantele.Combat.Skills.Performs.DagouBang.Chuo
    }
  end
end