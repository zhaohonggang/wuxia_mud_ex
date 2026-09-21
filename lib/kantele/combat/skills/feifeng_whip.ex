defmodule Kantele.Combat.Skills.FeifengWhip do
  @moduledoc """
  飞凤鞭法（对照 `kungfu/skill/feifeng-whip.c`）

  鞭法载体：`valid_enable("whip")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/feifeng_whip/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 还要求女性且持鞭，本版仅以 force>=30 代理；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "feifeng-whip"

  @impl true
  def valid_enable(usage), do: usage in ["whip", "parry"]

  @impl true
  def valid_learn(stats) do
    cond do
      Stats.skill(stats, "force") < 30 ->
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
    %{"wu" => Kantele.Combat.Skills.Performs.FeifengWhip.Wu}
  end
end