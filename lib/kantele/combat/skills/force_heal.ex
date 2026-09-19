defmodule Kantele.Combat.Skills.Force.Heal do
  @moduledoc """
  内功疗伤（对照 `kungfu/skill/force/heal.c`）

  自我疗伤：需非战斗、非忙碌、非天魔状态、已激发内功、
  eff_qi < max_qi、内功>=20、neili>=50、非(重伤且无 divine)。
  扣 neili 50；回复 eff_qi/qi = 10+force/3（divine +con*2，breakup *3），
  上限 max_qi。LPC 原为 async busy 循环，本引擎做单次版。

  eff_qi/max_qi 在本引擎折合 `vitals.max_qi`/`vitals.base_qi`（见 Vitals.wound）
  TODO(migrate): LPC healing 循环 → 单次回复；`special_skill/divine`、
  `breakup` 折合 `attributes["special_skills"]`。
  """

  use Kantele.Combat.Performs.Simple, spec: :local

  alias Kantele.Character.Combat
  alias Kantele.Character.SpecialSkills
  alias Kantele.Character.Stats
  alias Kantele.Combat.Performs.Spec

  def spec do
    %Spec{
      id: "force/heal",
      kind: :exert,
      gates: [
        {:custom, &gate_not_fighting/1, "战斗中运功疗伤？找死吗？\n"},
        {:custom, &gate_not_busy/1, "等你忙完了手头的事情再说！\n"},
        {:no_buff, "tianmo", "天魔解体状态不能运功疗伤！\n"},
        {:custom, &gate_has_force/1, "先激发你的特殊内功。\n"},
        {:custom, &gate_needs_heal/1, "你现在气血充盈，不需要疗伤。\n"},
        {:custom, &gate_force_level/1, "你的内功修为还不够。\n"},
        {:neili_min, 50, "你的真气不够。\n"},
        {:custom, &gate_not_critical_without_divine/1, "你已经受伤过重，只怕一运真气便有生命危险！\n"}
      ],
      costs: %{neili: 50},
      effects: [
        {:custom, &effect_heal/1}
      ],
      busy: 0,
      message: "$N全身放松，坐下来开始运功疗伤。\n"
    }
  end

  defp gate_not_fighting(ctx), do: not Combat.fighting?(ctx.character.meta.combat)

  defp gate_not_busy(ctx), do: not Combat.busy?(ctx.character.meta.combat)

  defp gate_has_force(ctx), do: Map.get(ctx.stats.mapped, "force") != nil

  defp gate_needs_heal(ctx) do
    v = ctx.character.meta.vitals
    v.max_qi < v.base_qi
  end

  defp gate_force_level(ctx) do
    Stats.skill(ctx.stats, Map.get(ctx.stats.mapped, "force") || "force") >= 20
  end

  defp gate_not_critical_without_divine(ctx) do
    v = ctx.character.meta.vitals
    divine? = SpecialSkills.owned?(ctx.character.attributes, "divine")

    v.max_qi >= div(v.base_qi, 5) || divine?
  end

  defp effect_heal(state) do
    char = state.character
    vitals = char.meta.vitals
    stats = char.meta.stats

    force_lvl = Stats.skill(stats, Map.get(stats.mapped, "force") || "force")
    cure = 10 + div(force_lvl, 3)
    cure = if SpecialSkills.owned?(char.attributes, "divine"), do: cure + Stats.query_con(stats) * 2, else: cure
    cure = if SpecialSkills.owned?(char.attributes, "breakup"), do: cure * 3, else: cure

    new_max = min(vitals.max_qi + cure, vitals.base_qi)
    new_vitals = %{vitals | max_qi: new_max, qi: min(vitals.qi + cure, new_max)}

    %{state | character: %{char | meta: %{char.meta | vitals: new_vitals}}}
  end
end