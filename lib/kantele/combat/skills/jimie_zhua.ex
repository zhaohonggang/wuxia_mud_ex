defmodule Kantele.Combat.Skills.JimieZhua do
  @moduledoc """
  寂灭爪（对照 `kungfu/skill/jimie-zhua.c`）

  爪法载体：`valid_enable("claw")` / `valid_enable("parry")`（须空手）。

  绝招实现见 `lib/kantele/combat/skills/performs/jimie_zhua/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 还要求空手与 max_neili>=600，本版以 force>=60 代理；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "jimie-zhua"

  @impl true
  def valid_enable(usage), do: usage in ["claw", "parry"]

  @doc "只能学(learn)不能练"
  @impl true
  def practice_cost(), do: nil

  # LPC `valid_learn(object me)`（源 jimie-zhua.c）
  @impl true
  def valid_learn(_stats, character) do
    max_neili = max_neili_of(character)

    cond do
      (Skill.wielding?(character)) or (Skill.secondary_wielding?(character)) ->
        {:error, "练寂灭爪必须空手。\n"}

      not is_nil(max_neili) and max_neili < 600 ->
        {:error, "你的内力太弱，无法学习寂灭爪。\n"}

      true ->
        :ok
    end
  end

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"wuwo" => Kantele.Combat.Skills.Performs.JimieZhua.Wuwo}
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil

end
