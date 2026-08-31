defmodule Kantele.Character.Vitals do
  @moduledoc """
  Character vital information

  Wuxia four vital lines:

  - qi - HP, death at 0
  - jing - Energy, affects actions (LPC jing; learn/study consumes)
  - jingli - Energy cultivation, improved by meditation (LPC jingli; non-recovery line)
  - neili - Internal force, used for special moves/internal skills
  """

  @derive Jason.Encoder
  defstruct [
    :qi,
    :max_qi,
    :base_qi,
    :jing,
    :max_jing,
    :base_jing,
    :jingli,
    :max_jingli,
    :neili,
    :max_neili,
    :base_neili
  ]

  @doc """
  Player default constitution: enough to survive a few rounds against Black Tiger

  base_* are the minimum below which wounds don't drop, natural recovery slowly raises max_* back to base
  """
  def new() do
    %__MODULE__{
      qi: 150,
      max_qi: 150,
      base_qi: 150,
      jing: 120,
      max_jing: 120,
      base_jing: 120,
      jingli: 0,
      max_jingli: 0,
      neili: 200,
      max_neili: 200,
      base_neili: 200
    }
  end

  @doc """
  Receive direct damage (LPC receive_damage/2), HP minimum 0
  """
  def damage(%__MODULE__{} = vitals, :qi, amount) when amount >= 0 do
    %{vitals | qi: max(vitals.qi - amount, 0)}
  end

  def damage(%__MODULE__{} = vitals, :jing, amount) when amount >= 0 do
    %{vitals | jing: max(vitals.jing - amount, 0)}
  end

  def damage(%__MODULE__{} = vitals, :jingli, amount) when amount >= 0 do
    %{vitals | jingli: max(vitals.jingli - amount, 0)}
  end

  @doc """
  Wound reduces max (LPC receive_wound/2 effect on eff_qi), clamps current value
  """
  def wound(%__MODULE__{} = vitals, :qi, amount) when amount >= 0 do
    max_qi = max(vitals.max_qi - amount, 1)
    vitals = %{vitals | max_qi: max_qi}
    %{vitals | qi: min(vitals.qi, max_qi)}
  end

  @doc """
  Healing effect (LPC receive_heal/3): raise current value toward max_*, not exceeding cap

  Opposite of damage, only raises current value, doesn't move wound cap.
  """
  def heal(%__MODULE__{} = vitals, :qi, amount) when amount >= 0,
    do: %{vitals | qi: min(vitals.qi + amount, vitals.max_qi)}

  def heal(%__MODULE__{} = vitals, :jing, amount) when amount >= 0,
    do: %{vitals | jing: min(vitals.jing + amount, vitals.max_jing)}

  def heal(%__MODULE__{} = vitals, :neili, amount) when amount >= 0,
    do: %{vitals | neili: min(vitals.neili + amount, vitals.max_neili)}

  @doc """
  Cure wound (LPC receive_curing/4 effect on eff_*): raise max_* lowered by wound
  back toward base_*, clamping current value to new max
  """
  def curing(%__MODULE__{} = vitals, :qi, amount) when amount >= 0 do
    max_qi = min(vitals.max_qi + amount, vitals.base_qi)
    %{vitals | max_qi: max_qi, qi: min(vitals.qi, max_qi)}
  end

  def curing(%__MODULE__{} = vitals, :jing, amount) when amount >= 0 do
    max_jing = min(vitals.max_jing + amount, vitals.base_jing)
    %{vitals | max_jing: max_jing, jing: min(vitals.jing, max_jing)}
  end

  def curing(%__MODULE__{} = vitals, :neili, amount) when amount >= 0 do
    max_neili = min(vitals.max_neili + amount, vitals.base_neili)
    %{vitals | max_neili: max_neili, neili: min(vitals.neili, max_neili)}
  end

  @doc """
  Natural regeneration: slow recovery of three lines in non-combat (simplified heal_up/9)

  Wounded max_* slowly recover toward base_*
  """
  def regenerate(%__MODULE__{} = vitals, stats, fighting?) do
    con = stats.con

    vitals
    |> regen(:qi, div(con * 2 + 10, regen_scale(fighting?)), vitals.max_qi)
    |> regen(:jing, div(con + 5, regen_scale(fighting?)), vitals.max_jing)
    |> regen(:neili, div(con * 2 + force_bonus(stats), regen_scale(fighting?)), vitals.max_neili)
    |> recover_max(:max_qi, :base_qi, max(div(con, 2), 1))
    |> recover_max(:max_jing, :base_jing, max(div(con, 2), 1))
    |> recover_max(:max_neili, :base_neili, max(div(con, 2), 1))
  end

  @doc """
  Recalculate max neili based on current force level (LPC query_max_neili)

  force base + special force bonus; called after meditation/training.
  """
  def recalculate_max_neili(%__MODULE__{} = vitals, stats) do
    alias Kantele.Character.NeiliLimit

    new_max = NeiliLimit.current(stats)

    # Meditation can store up to 2x max, recalculation clamps current value to new max x2
    neili = min(vitals.neili, new_max * 2)

    %{vitals | max_neili: new_max, neili: neili}
  end

  defp force_bonus(stats), do: div(Map.get(stats.skills, "force", 0), 3)
  defp regen_scale(true), do: 4
  defp regen_scale(false), do: 1

  defp regen(vitals, _key, _amount, 0), do: vitals

  defp regen(vitals, key, amount, max) do
    current = Map.get(vitals, key)

    # Meditation can let neili temporarily store up to 2x max, natural recovery only tops up, doesn't reduce
    if current < max do
      %{vitals | key => min(current + amount, max)}
    else
      vitals
    end
  end

  defp recover_max(vitals, max_key, base_key, amount) do
    base = Map.get(vitals, base_key)
    max = Map.get(vitals, max_key)

    # Only recover when wound reduced max (max < base); healthy state (including meditation stored neili > max) untouched
    if is_integer(base) and base > max do
      new_max = min(max + amount, base)
      vitals = %{vitals | max_key => new_max}
      clamp_current(vitals, max_key)
    else
      vitals
    end
  end

  defp clamp_current(vitals, :max_qi), do: %{vitals | qi: min(vitals.qi, vitals.max_qi)}
  defp clamp_current(vitals, :max_jing), do: %{vitals | jing: min(vitals.jing, vitals.max_jing)}

  defp clamp_current(vitals, :max_neili),
    do: %{vitals | neili: min(vitals.neili, vitals.max_neili)}
end
