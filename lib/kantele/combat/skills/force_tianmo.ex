defmodule Kantele.Combat.Skills.Force.Tianmo do
  @moduledoc """
  天魔解体大法（对照 `kungfu/skill/force/tianmo.c`）

  极限门槛：str>=30 且 con>=30、neili>=8000、shen <= -10000000、
  force>=300、martial-cognize>=300、非天魔状态。
  设 neili=0，扣 qi/jing（skill+shen_lvl+rand），
  临时全属性加成 + mapped 武学技能加成，busy 3。
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
    %{"tianmo" => __MODULE__}
  end

  def spec do
    %Kantele.Combat.Performs.Spec{
      id: "force/tianmo",
      kind: :exert,
      gates: [
        {:custom, &gate_self_only/1, "你只能提升自己的战斗力。\n"},
        {:custom, &gate_not_tianmo/1, "你已经在运功中了。\n"},
        {:custom, &gate_attributes/1, "你的资质不适合使用「天魔解体大法」。\n"},
        {:neili_min, 8000, "你的内力不够!\n"},
        {:custom, &gate_shen/1, "你还没有入魔，无法使用「天魔解体大法」。\n"},
        {:custom, &gate_skill_levels/1, "你的修行还不够,无法使用「天魔解体大法」。\n"}
      ],
      costs: %{},
      effects: [
        {:custom, &effect_tianmo/1}
      ],
      busy: {:if_fighting, 3},
      message: "$N蓦地大叫一声，喷出一口鲜血，正是天下闻名的「天魔解体大法」。\n"
    }
  end

  defp gate_self_only(_ctx), do: :ok

  defp gate_not_tianmo(ctx),
    do:
      if(not ctx.combat.buffs |> Enum.any?(&(&1.key == "tianmo")),
        do: :ok,
        else: {:error, "你已经在运功中了。\n"}
      )

  defp gate_attributes(ctx) do
    if ctx.character.meta.stats.str >= 30 && ctx.character.meta.stats.con >= 30,
      do: :ok,
      else: {:error, "你的资质不适合使用「天魔解体大法」。\n"}
  end

  defp gate_shen(ctx) do
    if (ctx.character.meta.stats.shen || 0) <= -10_000_000,
      do: :ok,
      else: {:error, "你还没有入魔，无法使用「天魔解体大法」。\n"}
  end

  defp gate_skill_levels(ctx) do
    force = Stats.skill(ctx.stats, "force")
    cognize = Stats.skill(ctx.stats, "martial-cognize")
    if force >= 300 && cognize >= 300, do: :ok, else: {:error, "你的修行还不够,无法使用「天魔解体大法」。\n"}
  end

  defp effect_tianmo(state) do
    char = state.character
    vitals = char.meta.vitals
    stats = char.meta.stats
    combat = char.meta.combat

    skill = Stats.skill(stats, "force")
    shen = stats.shen || 0
    shen_lvl = :math.sqrt(-shen) |> :math.pow(1.0 / 3) |> floor()
    count = div(shen_lvl + skill, 4)

    skills = Stats.mapped_combat_skills(stats) |> Map.keys()

    damage = skill + shen_lvl + :rand.uniform(1000)

    new_vitals = %{
      vitals
      | neili: 0,
        qi: max(vitals.qi - damage, 1),
        eff_qi: max(vitals.eff_qi - damage, 1),
        jing: max(vitals.jing - damage, 1),
        eff_jing: max(vitals.eff_jing - damage, 1)
    }

    applies = %{
      str: stats.str,
      int: stats.int,
      con: stats.con,
      dex: stats.dex,
      attack: count,
      damage: stats.str * 3,
      unarmed_damage: stats.str * 3
    }

    applies =
      Enum.reduce(skills, applies, fn skill_id, acc ->
        Map.put(acc, skill_id, div(count, 2))
      end)

    buff = %Kantele.Character.Combat.Buff{
      key: "tianmo",
      applies: Enum.reduce(applies, %{}, fn {k, v}, acc -> Map.put(acc, k, -v) end)
    }

    new_combat =
      combat
      |> Kantele.Character.Combat.apply_temp(applies)
      |> Kantele.Character.Combat.add_buff(buff)

    new_vitals = %{new_vitals | neili: 0}

    new_char = %{char | meta: %{char.meta | vitals: new_vitals, combat: new_combat}}

    %{state | character: new_char}
  end
end
