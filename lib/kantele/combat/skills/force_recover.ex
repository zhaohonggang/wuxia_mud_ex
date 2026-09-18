defmodule Kantele.Combat.Skills.Force.Recover do
  @moduledoc """
  内功调息（对照 `kungfu/skill/force/recover.c`）

  自我疗伤同步版：需 eff_qi > qi、neili>=20；
  扣 neili n=100*q/force（breakup/self技能减免），下限 20；
  回复 qi=q，无 busy（战斗中且无 self 技能 busy 1）。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "force"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(_force), do: true

  @impl true
  def valid_learn(_stats), do: :ok

  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def exert_list() do
    %{"recover" => __MODULE__}
  end

  def spec do
    %Kantele.Combat.Performs.Spec{
      id: "force/recover",
      kind: :exert,
      gates: [
        {:custom, &gate_self_only/1, "你只能用内功调匀自己的气息。\n"},
        {:custom, &gate_needs_heal/1, "你现在气力充沛。\n"},
        {:neili_min, 20, "你的内力不够。\n"}
      ],
      costs: %{},
      effects: [
        {:custom, &effect_recover/1}
      ],
      busy: {:if_fighting, 1},
      message: "$N深深吸了几口气，脸色看起来好多了。\n"
    }
  end

  defp gate_self_only(ctx) do
    # ExertCommand ensures target == self
    :ok
  end

  defp gate_needs_heal(ctx) do
    vitals = ctx.character.meta.vitals
    if vitals.qi < vitals.eff_qi, do: :ok, else: {:error, "你现在气力充沛。\n"}
  end

  defp effect_recover(state) do
    char = state.character
    vitals = char.meta.vitals
    stats = char.meta.stats

    q = vitals.eff_qi - vitals.qi
    force_lvl = Stats.skill(stats, char.meta.stats.mapped.force || "force")

    n = div(100 * q, max(force_lvl, 1))
    if stats.breakup, do: n = div(n * 7, 10)
    if n < 20, do: n = 20
    if Stats.special_skill(stats, "self"), do: n = div(n * 7, 10)

    n = min(n, vitals.neili)
    q = div(q * n, max(n, 1))

    new_vitals = %{
      vitals
      | neili: vitals.neili - n,
        qi: min(vitals.qi + q, vitals.eff_qi)
    }

    %{state | character: %{char | meta: %{char.meta | vitals: new_vitals}}}
  end
end
