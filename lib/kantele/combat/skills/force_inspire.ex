defmodule Kantele.Combat.Skills.Force.Inspire do
  @moduledoc """
  振奋精神（对照 `kungfu/skill/force/inspire.c`）

  自我回精：需打通任督（breakup）、非战斗、已激发内功、内功>=200、
  eff_jing < max_jing、eff_jing >= max_jing/4、neili>=200。
  扣 neili 100；回复 eff_jing/jing = 5+force/6，上限 max_jing。
  LPC 原为 async busy 循环，本引擎做单次版。

  eff_jing/max_jing 在本引擎折合 `vitals.max_jing`/`vitals.base_jing`（见 Vitals.wound）
  TODO(migrate): LPC inspiring 循环 → 单次回复；`breakup` 折合
  `attributes["special_skills"]`。
  """

  use Kantele.Combat.Performs.Simple, spec: :local

  alias Kantele.Character.Combat
  alias Kantele.Character.SpecialSkills
  alias Kantele.Character.Stats
  alias Kantele.Combat.Performs.Spec

  def spec do
    %Spec{
      id: "force/inspire",
      kind: :exert,
      gates: [
        {:custom, &gate_breakup/1, "你所学的内功中没有这种功能。\n"},
        {:custom, &gate_not_fighting/1, "现在你正在战斗中？还是等打完了再说吧！\n"},
        {:custom, &gate_has_force/1, "先激发你的特殊内功。\n"},
        {:custom, &gate_force_level/1, "你的内功修为还不够。\n"},
        {:custom, &gate_needs_jing/1, "你现在精神饱满，有什么好激励的？\n"},
        {:neili_min, 200, "你的真气不够。\n"},
        {:custom, &gate_not_critical/1, "你的精损伤太重，现在难以振奋自己。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:custom, &effect_inspire/1}
      ],
      busy: 0,
      message: "$N盘膝坐下，闭目冥神，缓缓的呼吸吐纳。\n"
    }
  end

  defp gate_breakup(ctx), do: SpecialSkills.owned?(ctx.character.attributes, "breakup")

  defp gate_not_fighting(ctx), do: not Combat.fighting?(ctx.character.meta.combat)

  defp gate_has_force(ctx), do: Map.get(ctx.stats.mapped, "force") != nil

  defp gate_force_level(ctx) do
    Stats.skill(ctx.stats, Map.get(ctx.stats.mapped, "force") || "force") >= 200
  end

  defp gate_needs_jing(ctx) do
    v = ctx.character.meta.vitals
    v.max_jing < v.base_jing
  end

  defp gate_not_critical(ctx) do
    v = ctx.character.meta.vitals
    v.max_jing >= div(v.base_jing, 4)
  end

  defp effect_inspire(state) do
    char = state.character
    vitals = char.meta.vitals
    stats = char.meta.stats

    force_lvl = Stats.skill(stats, Map.get(stats.mapped, "force") || "force")
    recover = 5 + div(force_lvl, 6)

    new_max = min(vitals.max_jing + recover, vitals.base_jing)
    new_vitals = %{vitals | max_jing: new_max, jing: min(vitals.jing + recover, new_max)}

    %{state | character: %{char | meta: %{char.meta | vitals: new_vitals}}}
  end
end