defmodule Kantele.Combat.Skills.LuohanQuan do
  @moduledoc """
  罗汉拳（对照 `kungfu/skill/luohan-quan.c`）

  拳法载体：`valid_enable("cuff")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/luohan_quan/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 门槛未建模；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  @impl true
  def id(), do: "luohan-quan"

  @impl true
  def valid_enable(usage), do: usage in ["cuff", "parry"]

  @impl true
  def valid_learn(_stats), do: :ok

  @doc "只能学(learn)不能练"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"xiangmo" => Kantele.Combat.Skills.Performs.LuohanQuan.Xiangmo}
  end
end