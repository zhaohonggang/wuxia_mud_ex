defmodule Kantele.Combat.Skills.Force.Power do
  @moduledoc """
  内功提升（对照 `kungfu/skill/force/power.c`）

  门槛：force>=200、martial-cognize>=120、neili>=100；
  找出已映射的武学技能中等级最高者（lev），
  设 neili=0，临时提升 apply/lev = martial-cognize/5，
  busy 3。
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
    %{"power" => __MODULE__}
  end

  def spec do
    %Kantele.Combat.Performs.Spec{
      id: "force/power",
      kind: :exert,
      gates: [
        {:custom, &gate_self_only/1, "你只能提升自己的战斗力。\n"},
        {:custom, &gate_force_level/1, "你的内功修为不够,无法提升自己的功力。\n"},
        {:custom, &gate_cognize_level/1, "你的武学修养不够,无法提升自己的功力。\n"},
        {:neili_min, 100, "你的内力不够！\n"},
        {:custom, &gate_no_power/1, "你已经在运功中了。\n"}
      ],
      costs: %{},
      effects: [
        {:custom, &effect_power/1}
      ],
      busy: {:if_fighting, 3},
      message: "$N纵声长笑，丹田中内力激荡，衣角悄然扬起，似乎要乘风而去，飘飘欲仙！\n"
    }
  end

  defp gate_self_only(_ctx), do: :ok

  defp gate_force_level(ctx),
    do:
      if(Stats.skill(ctx.stats, "force") >= 200, do: :ok, else: {:error, "你的内功修为不够,无法提升自己的功力。\n"})

  defp gate_cognize_level(ctx),
    do:
      if(Stats.skill(ctx.stats, "martial-cognize") >= 120,
        do: :ok,
        else: {:error, "你的武学修养不够,无法提升自己的功力。\n"}
      )

  defp gate_no_power(ctx),
    do:
      if(not ctx.combat.buffs |> Enum.any?(&(&1.key == "power")),
        do: :ok,
        else: {:error, "你已经在运功中了。\n"}
      )

  defp effect_power(state) do
    char = state.character
    stats = char.meta.stats
    vitals = char.meta.vitals
    combat = char.meta.combat

    # Find highest mapped combat skill level
    skills = Stats.mapped_combat_skills(stats)

    highest_skill =
      Enum.reduce(skills, {"force", 0}, fn {usage, skill_id}, {best, best_lev} ->
        lev = Stats.skill(stats, skill_id)
        if lev > best_lev, do: {skill_id, lev}, else: {best, best_lev}
      end)

    skill_id = elem(highest_skill, 0)
    cognize = Stats.skill(stats, "martial-cognize")
    bonus = div(cognize, 5)

    new_vitals = %{vitals | neili: 0}

    buff = %Kantele.Character.Combat.Buff{
      key: "power",
      applies: %{skill_id => -bonus}
    }

    new_combat =
      combat
      |> Kantele.Character.Combat.apply_temp(%{skill_id => bonus})
      |> Kantele.Character.Combat.add_buff(buff)

    new_char = %{char | meta: %{char.meta | vitals: new_vitals, combat: new_combat}}

    %{state | character: new_char}
  end
end
