defmodule Kantele.Combat.Skills.JingangZhi do
  @moduledoc """
  大力金刚指（对照 `kungfu/skill/jingang-zhi.c`）

  指法载体：`valid_enable("finger")` / `valid_enable("parry")`（须空手）。

  绝招实现见 `lib/kantele/combat/skills/performs/jingang_zhi/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 还要求空手、str>=30、con>=32、max_neili>=300、
    finger>=jingang-zhi，本版以 force>=60 代理；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "jingang-zhi"

  @impl true
  def valid_enable(usage), do: usage in ["finger", "parry"]

  @impl true
  def valid_learn(stats) do
    cond do
      Stats.skill(stats, "force") < 60 ->
        {:error, "你的内功火候不够，无法学大力金刚指。\n"}

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
    %{"fumo" => Kantele.Combat.Skills.Performs.JingangZhi.Fumo}
  end
end