defmodule Kantele.Combat.Skills.FireiceStrike do
  @moduledoc """
  烈焰寒冰掌（对照 `kungfu/skill/fireice-strike.c`）

  拳掌载体：`valid_enable("strike")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/fireice_strike/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 还要求空手、max_neili>=450，本版以 force>=100 代理；
  - LPC `main_skill("meinv-quan")` / `valid_combine` 合璧用法未建模；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "fireice-strike"

  @impl true
  def valid_enable(usage), do: usage in ["strike", "parry"]

  @impl true
  def valid_learn(stats) do
    cond do
      Stats.skill(stats, "force") < 100 ->
        {:error, "你的内功火候不够，无法练烈焰寒冰掌。\n"}

      true ->
        :ok
    end
  end

  @doc "只能学(learn)不能练"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"binghuo" => Kantele.Combat.Skills.Performs.FireiceStrike.Binghuo}
  end
end