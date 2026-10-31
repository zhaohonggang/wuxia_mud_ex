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

  alias Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "duoluoye-zhi"

  @impl true
  def valid_enable(usage), do: usage in ["finger", "parry"]

  @doc "只能学(learn)不能练"
  @impl true
  def practice_cost(), do: nil

  # LPC `valid_learn(object me)`（源 duoluoye-zhi.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      Stats.skill(stats, "canhe-zhi") > 0 ->
        {:error, "你已将这种指法融入参合指，不必再分开练习了。\n"}

      (Skill.wielding?(character)) or (Skill.secondary_wielding?(character)) ->
        {:error, "练多罗叶指必须空手。\n"}

      Stats.skill(stats, "force") < 150 ->
        {:error, "你的内功火候不够，无法学习多罗叶指。\n"}

      not is_nil(max_neili) and max_neili < 1500 ->
        {:error, "你的内力太弱，无法练多罗叶指。\n"}

      Stats.skill(stats, "finger") < lvl ->
        {:error, "你的基本指法水平有限，无法领会更高深的多罗叶指。\n"}

      true ->
        :ok
    end
  end

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"jimie" => Kantele.Combat.Skills.Performs.DuoluoyeZhi.Jimie}
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil

end
