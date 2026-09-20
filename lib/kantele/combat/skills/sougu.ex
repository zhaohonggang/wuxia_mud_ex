defmodule Kantele.Combat.Skills.Sougu do
  @moduledoc """
  搜骨鹰爪功（对照 `kungfu/skill/sougu.c`）

  爪/抓法载体：`valid_enable("claw")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/sougu/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 门槛未建模；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  @impl true
  def id(), do: "sougu"

  @impl true
  def valid_enable(usage), do: usage in ["claw", "parry"]

  @impl true
  def valid_learn(_stats), do: :ok

  @doc "只能学(learn)不能练"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"muyeyingyang" => Kantele.Combat.Skills.Performs.Sougu.Muyeyingyang}
  end
end