defmodule Kantele.Combat.Skills.HuoyanDao do
  @moduledoc """
  火焰刀（对照 `kungfu/skill/huoyan-dao.c`）

  掌法载体：`valid_enable("strike")` / `valid_enable("parry")`（须空手）。

  绝招实现见 `lib/kantele/combat/skills/performs/huoyan_dao/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 还要求空手、con>=32、shen 与 max_neili>=1200、
    strike>=huoyan-dao，本版以 force>=150 代理；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "huoyan-dao"

  @impl true
  def valid_enable(usage), do: usage in ["strike", "parry"]

  @impl true
  def valid_learn(stats) do
    cond do
      Stats.skill(stats, "force") < 150 ->
        {:error, "你的内功火候太浅。\n"}

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
    %{"fen" => Kantele.Combat.Skills.Performs.HuoyanDao.Fen}
  end
end