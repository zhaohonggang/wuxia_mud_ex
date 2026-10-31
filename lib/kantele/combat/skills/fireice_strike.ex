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

  alias Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "fireice-strike"

  @impl true
  def valid_enable(usage), do: usage in ["strike", "parry"]

  @doc "只能学(learn)不能练"
  @impl true
  def practice_cost(), do: nil

  # LPC `valid_learn(object me)`（源 fireice-strike.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      (Skill.wielding?(character)) or (Skill.secondary_wielding?(character)) ->
        {:error, "练烈焰寒冰掌必须空手。\n"}

      Stats.skill(stats, "force") < 100 ->
        {:error, "你的内功火候不够，无法练烈焰寒冰掌。\n"}

      not is_nil(max_neili) and max_neili < 450 ->
        {:error, "你的内力太弱，无法练烈焰寒冰掌。\n"}

      Stats.skill(stats, "strike") < lvl ->
        {:error, "你的基本掌法水平有限，无法领会更高深的烈焰寒冰掌。\n"}

      true ->
        :ok
    end
  end

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"binghuo" => Kantele.Combat.Skills.Performs.FireiceStrike.Binghuo}
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil

end
