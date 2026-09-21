defmodule Kantele.Combat.Skills.HuifengJian do
  @moduledoc """
  回风拂柳剑法（对照 `kungfu/skill/huifeng-jian.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/huifeng_jian/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 还要求 max_neili>=1200，本版以 force>=100 代理；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "huifeng-jian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "parry"]

  @impl true
  def valid_learn(stats) do
    cond do
      Stats.skill(stats, "force") < 100 ->
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
    %{
      "jue" => Kantele.Combat.Skills.Performs.HuifengJian.Jue,
      "mie" => Kantele.Combat.Skills.Performs.HuifengJian.Mie
    }
  end
end