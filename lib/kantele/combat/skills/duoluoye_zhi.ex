defmodule Kantele.Combat.Skills.DuoluoyeZhi do
  @moduledoc """
  多罗叶指（对照 `kungfu/skill/duoluoye-zhi.c`）

  指法载体：`valid_enable("finger")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/duoluoye_zhi/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 还要求空手、max_neili>=1500、未并入参合指，
    本版以 force>=150 代理；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "duoluoye-zhi"

  @impl true
  def valid_enable(usage), do: usage in ["finger", "parry"]

  @impl true
  def valid_learn(stats) do
    cond do
      Stats.skill(stats, "force") < 150 ->
        {:error, "你的内功火候不够，无法学习多罗叶指。\n"}

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
    %{"jimie" => Kantele.Combat.Skills.Performs.DuoluoyeZhi.Jimie}
  end
end