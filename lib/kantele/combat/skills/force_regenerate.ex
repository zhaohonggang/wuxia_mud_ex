defmodule Kantele.Combat.Skills.Force.Regenerate do
  @moduledoc """
  内功疗精（对照 `kungfu/skill/force/regenerate.c`）

  自我回精：需 eff_jing-jing>=10、neili>=20、内功>=1。
  扣 neili=heal*60/force（breakup ×7/10），下限 20，上限 neili；
  回复 jing=heal（上限 eff_jing）。单次版；战斗中 busy 1。
  """

  use Kantele.Combat.Performs.Simple, spec: :local

  alias Kantele.Character.SpecialSkills
  alias Kantele.Character.Stats
  alias Kantele.Combat.Performs.Spec

  def spec do
    %Spec{
      id: "force/regenerate",
      kind: :exert,
      gates: [
        {:neili_min, 20, "你的内力不够。\n"},
        {:custom, &gate_needs_jing/1, "你现在精气旺盛。\n"}
      ],
      costs: %{},
      effects: [
        {:custom, &effect_regenerate/1}
      ],
      busy: {:if_fighting, 1},
      message: "$N深深吸了几口气，精神看起来好多了。\n"
    }
  end

  defp gate_needs_jing(ctx) do
    v = ctx.character.meta.vitals
    v.max_jing - v.jing >= 10
  end

  defp effect_regenerate(state) do
    char = state.character
    vitals = char.meta.vitals
    stats = char.meta.stats

    heal = vitals.max_jing - vitals.jing
    force_lvl = max(Stats.skill(stats, "force"), 1)

    neili_cost = div(heal * 60, force_lvl)
    neili_cost = if SpecialSkills.owned?(char.attributes, "breakup"), do: div(neili_cost * 7, 10), else: neili_cost
    neili_cost = if neili_cost < 20, do: 20, else: neili_cost

    {neili_cost, heal} =
      if neili_cost > vitals.neili do
        {vitals.neili, div(vitals.neili * force_lvl, 60)}
      else
        {neili_cost, heal}
      end

    neili_cost = if neili_cost < 20, do: 20, else: neili_cost

    new_vitals = %{vitals | neili: vitals.neili - neili_cost, jing: min(vitals.jing + heal, vitals.max_jing)}

    %{state | character: %{char | meta: %{char.meta | vitals: new_vitals}}}
  end
end