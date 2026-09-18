defmodule Kantele.Combat.Skills.Force.Heal do
  @moduledoc """
  内功疗伤（对照 `kungfu/skill/force/heal.c`）

  自我疗伤：需非战斗、非忙碌、非天魔、有内功、eff_qi < max_qi、
  内功>=20、neili>=50、非(重伤且无divine)。
  扣 neili 50，回复 qi=10+force/3（divine/breakup加成）。
  单次版（原为 async busy 循环）。
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
    %{"heal" => __MODULE__}
  end

  def spec do
    %Kantele.Combat.Performs.Spec{
      id: "force/heal",
      kind: :exert,
      gates: [
        {:custom, &gate_not_fighting/1, "战斗中运功疗伤？找死吗？\n"},
        {:custom, &gate_not_busy/1, "等你忙完了手头的事情再说！\n"},
        {:custom, &gate_not_tianmo/1, "天魔解体状态不能运功疗伤！\n"},
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

  defp gate_not_fighting(ctx),
    do:
      if(not ctx.character.meta.combat.busy > 0 || Enum.empty?(ctx.character.meta.combat.enemies),
        do: :ok,
        else: {:error, "战斗中运功疗伤？找死吗？\n"}
      )

  defp gate_not_busy(ctx),
    do:
      if(ctx.character.meta.temp.pending_healing == nil,
        do: :ok,
        else: {:error, "等你忙完了手头的事情再说！\n"}
      )

  defp gate_not_tianmo(ctx),
    do:
      if(not ctx.combat.buffs |> Enum.any?(&(&1.key == "tianmo")),
        do: :ok,
        else: {:error, "天魔解体状态不能运功疗伤！\n"}
      )

  defp gate_has_force(ctx),
    do: if(ctx.stats.mapped.force, do: :ok, else: {:error, "先激发你的特殊内功。\n"})

  defp gate_needs_heal(ctx),
    do:
      if(ctx.character.meta.vitals.qi < ctx.character.meta.vitals.max_qi,
        do: :ok,
        else: {:error, "你现在气血充盈，不需要疗伤。\n"}
      )

  defp gate_force_level(ctx),
    do:
      if(Stats.skill(ctx.stats, ctx.stats.mapped.force) >= 20,
        do: :ok,
        else: {:error, "你的内功修为还不够。\n"}
      )

  defp gate_not_critical_without_divine(ctx) do
    vitals = ctx.character.meta.vitals
    has_divine = ctx.character.meta.temp.divine_skill || false

    if vitals.qi >= div(vitals.max_qi, 5) || has_divine,
      do: :ok,
      else: {:error, "你已经受伤过重，只怕一运真气便有生命危险！\n"}
  end

  defp effect_heal(state) do
    char = state.character
    vitals = char.meta.vitals
    stats = char.meta.stats

    force_lvl = Stats.skill(stats, char.meta.stats.mapped.force)
    cure = 10 + div(force_lvl, 3)
    if stats.divine_skill, do: cure = cure + stats.con * 2
    if stats.breakup, do: cure = cure * 3

    new_vitals = %{
      vitals
      | neili: vitals.neili - 50,
        qi: min(vitals.qi + cure, vitals.eff_qi)
    }

    %{state | character: %{char | meta: %{char.meta | vitals: new_vitals}}}
  end
end
