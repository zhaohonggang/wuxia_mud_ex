defmodule Kantele.Combat.Skills.JinsheZhui do
  @moduledoc """
  金蛇锥法（对照 `kungfu/skill/jinshe-zhui.c`）

  暗器/锥法载体：`valid_enable("throwing")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/jinshe_zhui/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 门槛未建模；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  @impl true
  def id(), do: "jinshe-zhui"

  @impl true
  def valid_enable(usage), do: usage in ["throwing", "parry"]

  @impl true
  def valid_learn(_stats), do: :ok

  @doc "只能学(learn)不能练"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"tuwu" => Kantele.Combat.Skills.Performs.JinsheZhui.Tuwu}
  end
end