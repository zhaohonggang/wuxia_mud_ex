defmodule Kantele.Combat.Skills.HujiaDaofa do
  @moduledoc """
  胡家刀法（对照 `kungfu/skill/hujia-daofa.c`）

  刀法载体：`valid_enable("blade")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/hujia_daofa/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 还要求 max_neili>=1400 且未习得 daojian-guizhen，
    本版以 force>=80 代理（互斥项未建模）；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "hujia-daofa"

  @impl true
  def valid_enable(usage), do: usage in ["blade", "parry"]

  @impl true
  def valid_learn(stats) do
    cond do
      Stats.skill(stats, "force") < 80 ->
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
    %{"xian" => Kantele.Combat.Skills.Performs.HujiaDaofa.Xian}
  end
end