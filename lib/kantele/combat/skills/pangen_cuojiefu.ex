defmodule Kantele.Combat.Skills.PangenCuojiefu do
  @moduledoc """
  盘根错节斧（对照 `kungfu/skill/pangen-cuojiefu.c`）

  斧/锤法载体：`valid_enable("hammer")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/pangen_cuojiefu/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 门槛未建模；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  @impl true
  def id(), do: "pangen-cuojiefu"

  @impl true
  def valid_enable(usage), do: usage in ["hammer", "parry"]

  @impl true
  def valid_learn(_stats), do: :ok

  @doc "只能学(learn)不能练"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"cuo" => Kantele.Combat.Skills.Performs.PangenCuojiefu.Cuo}
  end
end