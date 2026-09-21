defmodule Kantele.Combat.Skills.FeilongZhang do
  @moduledoc """
  飞龙杖法（对照 `kungfu/skill/feilong-zhang.c`）

  杖法载体：`valid_enable("staff")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/feilong_zhang/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 还要求持杖、max_neili>=500，本版以 force>=80 代理；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "feilong-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["staff", "parry"]

  @impl true
  def valid_learn(stats) do
    cond do
      Stats.skill(stats, "force") < 80 ->
        {:error, "你的内功修为不够，难以修炼飞龙杖法。\n"}

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
    %{"fei" => Kantele.Combat.Skills.Performs.FeilongZhang.Fei}
  end
end