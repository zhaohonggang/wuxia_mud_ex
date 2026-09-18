defmodule Kantele.Combat.Skills.Force.Lifeheal do
  @moduledoc """
  他人疗伤（对照 `kungfu/skill/force/lifeheal.c`）

  目标疗伤：需非战斗、目标存活、有内功、内功>=50、
  max_neili>=300、neili>=150、目标 eff_qi < max_qi、
  目标 eff_qi >= max_qi/5。
  扣 neili 150，目标回复 qi=10+force/2、eff_qi=10+force/3（上限 max_qi）。
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
    %{"lifeheal" => __MODULE__}
  end

  def spec do
    %Kantele.Combat.Performs.Spec{
      id: "force/lifeheal",
      kind: :exert,
      gates: [
        {:custom, &gate_not_fighting/1, "战斗中无法运功疗伤！\n"},
        {:custom, &gate_target_alive/1, "你不能给已死亡者疗伤。\n"},
        {:custom, &gate_has_force/1, "你必须激发一种内功才能替人疗伤。\n"},
        {:custom, &gate_force_level/1, "你的内功等级不够。\n"},
        {:max_neili_min, 300, "你的内力修为不够。\n"},
        {:neili_min, 150, "你现在的真气不够。\n"},
        {:custom, &gate_target_needs_heal/1, "目标现在没有受伤，不需要你运功治疗！\n"},
        {:custom, &gate_target_not_critical/1, "目标已经受伤过重，经受不起你的真气震荡！\n"}
      ],
      costs: %{neili: 150},
      effects: [
        {:custom, &effect_lifeheal/1}
      ],
      busy: 0,
      message: fn ctx ->
        target = ctx.target
        force_name = to_chinese(ctx.stats.mapped.force)

        "$N坐了下来运起#{force_name}，将手掌贴在#{target.name}背心，缓缓地将真气输入#{target.name}体内....\n过了不久，$N额头上冒出豆大的汗珠，#{
          target.name
        }吐出一口瘀血，脸色看起来红润多了。\n"
      end
    }
  end

  defp gate_not_fighting(ctx),
    do:
      if(not ctx.character.meta.combat.busy > 0 || Enum.empty?(ctx.character.meta.combat.enemies),
        do: :ok,
        else: {:error, "战斗中无法运功疗伤！\n"}
      )

  defp gate_target_alive(ctx),
    do: if(ctx.target && ctx.target.meta.vitals.qi > 0, do: :ok, else: {:error, "你不能给已死亡者疗伤。\n"})

  defp gate_has_force(ctx),
    do: if(ctx.stats.mapped.force, do: :ok, else: {:error, "你必须激发一种内功才能替人疗伤。\n"})

  defp gate_force_level(ctx),
    do:
      if(Stats.skill(ctx.stats, ctx.stats.mapped.force) >= 50,
        do: :ok,
        else: {:error, "你的内功等级不够。\n"}
      )

  defp gate_target_needs_heal(ctx) do
    if ctx.target.meta.vitals.eff_qi < ctx.target.meta.vitals.max_qi,
      do: :ok,
      else: {:error, "目标现在没有受伤，不需要你运功治疗！\n"}
  end

  defp gate_target_not_critical(ctx) do
    if ctx.target.meta.vitals.eff_qi >= div(ctx.target.meta.vitals.max_qi, 5),
      do: :ok,
      else: {:error, "目标已经受伤过重，经受不起你的真气震荡！\n"}
  end

  defp effect_lifeheal(state) do
    char = state.character
    target = state.target
    vitals = char.meta.vitals
    t_vitals = target.meta.vitals
    stats = char.meta.stats

    force_lvl = Stats.skill(stats, char.meta.stats.mapped.force)
    cure_eff = 10 + div(force_lvl, 2)
    cure_qi = 10 + div(force_lvl, 3)

    new_t_vitals = %{
      t_vitals
      | eff_qi: min(t_vitals.eff_qi + cure_eff, t_vitals.max_qi),
        qi: min(t_vitals.qi + cure_qi, t_vitals.eff_qi)
    }

    new_vitals = %{vitals | neili: vitals.neili - 150}

    new_target = %{target | meta: %{target.meta | vitals: new_t_vitals}}
    new_char = %{char | meta: %{char.meta | vitals: new_vitals}}

    %{state | character: new_char, target: new_target}
  end

  defp to_chinese(name) do
    case name do
      "hunyuan-yiqi" -> "混元一气"
      "taiji-shengong" -> "太极神功"
      "xiaowuxiang" -> "小无相"
      _ -> name
    end
  end
end
