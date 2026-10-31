defmodule Kantele.Combat.Skills.JingangZhi do
  @moduledoc """
  大力金刚指（对照 `kungfu/skill/jingang-zhi.c`）

  指法载体：`valid_enable("finger")` / `valid_enable("parry")`（须空手）。

  绝招实现见 `lib/kantele/combat/skills/performs/jingang_zhi/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 还要求空手、str>=30、con>=32、max_neili>=300、
    finger>=jingang-zhi，本版以 force>=60 代理；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "jingang-zhi"

  @impl true
  def valid_enable(usage), do: usage in ["finger", "parry"]

  @doc "只能学(learn)不能练"
  @impl true
  def practice_cost(), do: nil

  # LPC `valid_learn(object me)`（源 jingang-zhi.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      (Skill.wielding?(character)) or (Skill.secondary_wielding?(character)) ->
        {:error, "练大力金刚指必须空手。\n"}

      Stats.skill(stats, "force") < 60 ->
        {:error, "你的内功火候不够，无法学大力金刚指。\n"}

      (Stats.str(stats) < 30) or (Stats.con(stats) < 32) ->
        {:error, "你的先天条件不够，无法学大力金刚指。\n"}

      not is_nil(max_neili) and max_neili < 300 ->
        {:error, "你的内力太弱，无法练大力金刚指。\n"}

      Stats.skill(stats, "finger") < lvl ->
        {:error, "你的基本指法水平有限，无法领会更高深的大力金刚指。\n"}

      true ->
        :ok
    end
  end

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{
      "fumo" => Kantele.Combat.Skills.Performs.JingangZhi.Fumo,
      "san" => Kantele.Combat.Skills.Performs.JingangZhi.San
    }
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil

end
