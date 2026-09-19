defmodule Kantele.Combat.Skills.Force.Recover do
  @moduledoc """
  内功调息（对照 `kungfu/skill/force/recover.c`）

  自我调息同步版：需 neili>=20、eff_qi-qi>=10。
  扣 neili n=100*q/force（breakup/self 技能 ×7/10），下限 20，上限 neili；
  回复 qi=q（上限 eff_qi）。战斗中且无 self 技能 busy 1；
  TODO(migrate): busy 的 `!special_skill/self` 条件无法用声明式表达，简化为
  战斗中一律 busy 1。
  """

  use Kantele.Combat.Performs.Simple, spec: :local

  alias Kantele.Character.SpecialSkills
  alias Kantele.Character.Stats
  alias Kantele.Combat.Performs.Spec

  def spec do
    %Spec{
      id: "force/recover",
      kind: :exert,
      gates: [
        {:neili_min, 20, "你的内力不够。\n"},
        {:custom, &gate_needs_heal/1, "你现在气力充沛。\n"}
      ],
      costs: %{},
      effects: [
        {:custom, &effect_recover/1}
      ],
      busy: {:if_fighting, 1},
      message: "$N深深吸了几口气，脸色看起来好多了。\n"
    }
  end

  defp gate_needs_heal(ctx) do
    v = ctx.character.meta.vitals
    v.max_qi - v.qi >= 10
  end

  defp effect_recover(state) do
    char = state.character
    vitals = char.meta.vitals
    stats = char.meta.stats

    q = vitals.max_qi - vitals.qi
    force_lvl = max(Stats.skill(stats, "force"), 1)

    n = div(100 * q, force_lvl)
    n = if SpecialSkills.owned?(char.attributes, "breakup"), do: div(n * 7, 10), else: n
    n = if n < 20, do: 20, else: n
    n = if SpecialSkills.owned?(char.attributes, "self"), do: div(n * 7, 10), else: n

    {n, q} =
      if vitals.neili < n do
        {vitals.neili, div(q * vitals.neili, n)}
      else
        {n, q}
      end

    new_vitals = %{vitals | neili: vitals.neili - n, qi: min(vitals.qi + q, vitals.max_qi)}

    %{state | character: %{char | meta: %{char.meta | vitals: new_vitals}}}
  end
end