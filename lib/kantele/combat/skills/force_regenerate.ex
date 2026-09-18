defmodule Kantele.Combat.Skills.Force.Regenerate do
  @moduledoc """
  内功疗精（对照 `kungfu/skill/force/regenerate.c`）

  自我回精：需劲力亏损、neili>=20、内功>=1。
  扣 neili=heal*60/force（breakup减免），下限 20，上限 neili；
  回复 jing=heal（上限 eff_jing）。单次执行版（原为 async busy 循环）。
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
    %{"regenerate" => __MODULE__}
  end

  def spec do
    %Kantele.Combat.Performs.Spec{
      id: "force/regenerate",
      kind: :exert,
      gates: [
        {:custom, &gate_self_only/1, "你只能用内功恢复自己的精力。\n"},
        {:custom, &gate_needs_jing/1, "你现在精气旺盛。\n"},
        {:neili_min, 20, "你的内力不够。\n"}
      ],
      costs: %{},
      effects: [
        {:custom, &effect_regenerate/1}
      ],
      busy: 0,
      message: "$N深深吸了几口气，精神看起来好多了。\n"
    }
  end

  defp gate_self_only(_ctx), do: :ok

  defp gate_needs_jing(ctx) do
    v = ctx.character.meta.vitals
    if v.jing < v.eff_jing, do: :ok, else: {:error, "你现在精气旺盛。\n"}
  end

  defp effect_regenerate(state) do
    char = state.character
    vitals = char.meta.vitals
    stats = char.meta.stats

    heal = vitals.eff_jing - vitals.jing
    if heal < 10 do
      state
    else
      force_lvl = Stats.skill(stats, "force")
      force_lvl = max(force_lvl, 1)
      neili_cost = div(heal * 60, force_lvl)
      if stats.breakup, do: neili_cost = div(neili_cost * 7, 10)
      if neili_cost < 20, do: neili_cost = 20
      if neili_cost > vitals.neili do
        neili_cost = vitals.neili
        heal = div(neili_cost * force_lvl, 60)
      end
      if neili_cost < 20, do: neili_cost = 20

      new_vitals = %{
        vitals
        | neili: vitals.neili - neili_cost,
          jing: min(vitals.jing + heal, vitals.eff_jing)
      }

      %{state | character: %{char | meta: %{char.meta | vitals: new_vitals}}}
    end
  end
end
