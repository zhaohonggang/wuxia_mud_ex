defmodule Kantele.Combat.Skills.BaibianDaxue do
  @moduledoc """
  百变大学（对照 `kungfu/skill/baibian-daxue.c`）

  杖/棍法载体：`valid_enable("staff")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/baibian_daxue/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 门槛未建模；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  @impl true
  def id(), do: "baibian-daxue"

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
    %{"dian" => Kantele.Combat.Skills.Performs.BaibianDaxue.Dian}
  end
end