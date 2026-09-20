defmodule Kantele.Combat.Skills.JinguanYusuo do
  @moduledoc """
  金刚玉锁（对照 `kungfu/skill/jinguan-yusuo.c`）

  内功/锁法载体：`valid_enable("force")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/jinguan_yusuo/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 门槛未建模；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  @impl true
  def id(), do: "jinguan-yusuo"

  @impl true
  def valid_enable(usage), do: usage in ["force", "parry"]

  @impl true
  def valid_learn(_stats), do: :ok

  @doc "只能学(learn)不能练"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"suo" => Kantele.Combat.Skills.Performs.JinguanYusuo.Suo}
  end
end