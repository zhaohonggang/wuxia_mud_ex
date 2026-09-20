defmodule Kantele.Combat.Skills.ChuanxinZhang do
  @moduledoc """
  穿心掌法（对照 `kungfu/skill/chuanxin-zhang.c`）

  掌法载体：`valid_enable("strike")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/chuanxin_zhang/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 门槛未建模；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  @impl true
  def id(), do: "chuanxin-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["strike", "parry"]

  @impl true
  def valid_learn(_stats), do: :ok

  @doc "只能学(learn)不能练"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"zhui" => Kantele.Combat.Skills.Performs.ChuanxinZhang.Zhui}
  end
end