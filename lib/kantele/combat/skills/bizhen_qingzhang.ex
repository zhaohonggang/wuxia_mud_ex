defmodule Kantele.Combat.Skills.BizhenQingzhang do
  @moduledoc """
  裨阵清掌（对照 `kungfu/skill/bizhen-qingzhang.c`）

  掌法载体：`valid_enable("strike")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/bizhen_qingzhang/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 门槛未建模；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  @impl true
  def id(), do: "bizhen-qingzhang"

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
    %{"pengpai" => Kantele.Combat.Skills.Performs.BizhenQingzhang.Pengpai}
  end
end