defmodule Kantele.Combat.Skills.FengleiPanfa do
  @moduledoc """
  风雷盘法（对照 `kungfu/skill/fenglei-panfa.c`）

  锤法载体：`valid_enable("hammer")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/fenglei_panfa/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 还要求 max_neili>=800，本版以 force>=120 代理；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "fenglei-panfa"

  @impl true
  def valid_enable(usage), do: usage in ["hammer", "parry"]

  @doc "只能学(learn)不能练"
  @impl true
  def practice_cost(), do: nil

  # LPC `valid_learn(object me)`（源 fenglei-panfa.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 800 ->
        {:error, "你的内力不够。\n"}

      Stats.skill(stats, "force") < 120 ->
        {:error, "你的内功火候太浅。\n"}

      Stats.skill(stats, "hammer") < lvl ->
        {:error, "你的基本锤法水平有限，无法领会更高深的风雷盘法。\n"}

      true ->
        :ok
    end
  end

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"fenglei" => Kantele.Combat.Skills.Performs.FengleiPanfa.Fenglei}
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil

end
