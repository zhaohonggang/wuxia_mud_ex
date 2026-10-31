defmodule Kantele.Combat.Skills.HongyeDaofa do
  @moduledoc """
  红叶刀法（对照 `kungfu/skill/hongye-daofa.c`）

  刀法载体：`valid_enable("blade")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/hongye_daofa/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 还要求 max_neili>=1000、hunyuan-yiqi>=80、int>=24，
    本版以 force>=80 代理；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "hongye-daofa"

  @impl true
  def valid_enable(usage), do: usage in ["blade", "parry"]

  @doc "只能学(learn)不能练"
  @impl true
  def practice_cost(), do: nil

  # LPC `valid_learn(object me)`（源 hongye-daofa.c）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 1000 ->
        {:error, "你的内力不够。\n"}

      Stats.skill(stats, "hunyuan-yiqi") < 80 ->
        {:error, "你的混元一气内功火候太浅。\n"}

      Stats.skill(stats, "blade") < 80 ->
        {:error, "你的基本刀法火候太浅。\n"}

      Stats.int(stats) < 24 ->
        {:error, "你的先天悟性不足。\n"}

      true ->
        :ok
    end
  end

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{
      "kuang" => Kantele.Combat.Skills.Performs.HongyeDaofa.Kuang,
      "leiting" => Kantele.Combat.Skills.Performs.HongyeDaofa.Leiting
    }
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil

end
