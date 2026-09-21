defmodule Kantele.Combat.Skills.JidianJian do
  @moduledoc """
  疾电剑法（对照 `kungfu/skill/jidian-jian.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/jidian_jian/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 还要求 max_neili>=200、dodge>=60、dex>=25、
    sword>=jidian-jian，本版以 force>=50 代理；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "jidian-jian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "parry"]

  @impl true
  def valid_learn(stats) do
    cond do
      Stats.skill(stats, "force") < 50 ->
        {:error, "你的内力不够，无法修习疾电剑法。\n"}

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
    %{"dian" => Kantele.Combat.Skills.Performs.JidianJian.Dian}
  end
end