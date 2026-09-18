defmodule Kantele.Combat.Skills.Force.Inspire do
  @moduledoc """
  振奋精神（对照 `kungfu/skill/force/inspire.c`）

  自我回精：需打通任督、非战斗、有内功、内功>=200、
  eff_jing < max_jing、eff_jing >= max_jing/4、neili>=200。
  扣 neili 100/回合，回复 jing=5+force/6（单次版）。
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
    %{"inspire" => __MODULE__}
  end

  def spec do
    %Kantele.Combat.Performs.Spec{
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

  defp gate_breakup(ctx) do
    if Stats.special_skill(ctx.character.meta.stats, "breakup"),
      do: :ok,
      else: {:error, "你所学的内功中没有这种功能。\n"}
  end

  defp gate_not_fighting(ctx),
    do:
      if(not ctx.character.meta.combat.busy > 0 || Enum.empty?(ctx.character.meta.combat.enemies),
        do: :ok,
        else: {:error, "现在你正在战斗中？还是等打完了再说吧！\n"}
      )

  defp gate_has_force(ctx),
    do: if(ctx.stats.mapped.force, do: :ok, else: {:error, "先激发你的特殊内功。\n"})

  defp gate_force_level(ctx) do
    force_lvl = Stats.skill(ctx.stats, ctx.stats.mapped.force)
    if force_lvl >= 200, do: :ok, else: {:error, "你的内功修为还不够。\n"}
  end

  defp gate_needs_jing(ctx) do
    v = ctx.character.meta.vitals
    if v.eff_jing < v.max_jing, do: :ok, else: {:error, "你现在精神饱满，有什么好激励的？\n"}
  end

  defp gate_not_critical(ctx) do
    v = ctx.character.meta.vitals
    if v.eff_jing >= div(v.max_jing, 4), do: :ok, else: {:error, "你的精损伤太重，现在难以振奋自己。\n"}
  end

  defp effect_inspire(state) do
    char = state.character
    vitals = char.meta.vitals
    stats = char.meta.stats

    force_lvl = Stats.skill(stats, char.meta.stats.mapped.force)
    recover = 5 + div(force_lvl, 6)

    new_vitals = %{
      vitals
      | neili: vitals.neili - 100,
        eff_jing: min(vitals.eff_jing + recover, vitals.max_jing)
    }

    %{state | character: %{char | meta: %{char.meta | vitals: new_vitals}}}
  end
end
