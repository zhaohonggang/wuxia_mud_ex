defmodule Kantele.Item.Equip do
  @moduledoc """
  装备/卸下护甲与武器（对应 `feature/equip.c`）

  纯决策 + 纯属性合并，供宿主 wield_command/combat 接入：

  - `two_handed?/1` / `secondary?/1`: 读 LPC 武器 flag 位（TWO_HANDED / SECONDARY）
  - `wield_decision/3`: 双手/单手/副手/换手决策，返回占用槽位或 `{:error, msg}`
  - `wield_state/2`/`unequip_state/2`: 应用/扣减武器 prop 到 temp_applies
  - `wear_state/3`: 护甲合并（armor + prop）

  `flag` 值取自 LPC weapon.h：ONE_HANDED=0x1, SECONDARY=0x2, TWO_HANDED=0x4。
  位运算用 `:erlang.band/2`（Elixir 1.11 无 `&&&`）。
  """

  @two_handed 0x4
  @secondary 0x2

  @doc "是否双手武器 (LPC: flag & TWO_HANDED)"
  def two_handed?(flag), do: is_integer(flag) and :erlang.band(flag, @two_handed) != 0

  @doc "是否可作副手 (LPC: flag & SECONDARY)"
  def secondary?(flag), do: is_integer(flag) and :erlang.band(flag, @secondary) != 0

  @doc """
  双手/单手决策 (LPC: wield 主流程)

  state: `%{weapon: snap|nil, secondary_weapon: snap|nil, handing: id|nil}`
  返回 `{:slot}`（:weapon/:secondary_weapon/:swap）或 `{:error, msg}`。
  """
  def wield_decision(flag, state) do
    %{weapon: weapon, secondary_weapon: secondary, handing: handing} = state

    cond do
      two_handed?(flag) ->
        if secondary != nil or weapon != nil or handing != nil do
          {:error, "你必须空出双手才能装备该武器。"}
        else
          {:weapon}
        end

      weapon == nil ->
        {:weapon}

      secondary == nil and handing == nil ->
        if secondary?(flag) do
          {:secondary_weapon}
        else
          old_flag = if is_map(weapon), do: Map.get(weapon, :flag, 0), else: 0

          if secondary?(old_flag) do
            {:swap}
          else
            {:error, "你必须先放下你目前装备的武器。"}
          end
        end

      true ->
        {:error, "你必须空出一只手来使用武器。"}
    end
  end

  @doc "应用武器 prop 到 applies（LPC 累加到 temp/apply）。返回新 applies。"
  def wield_state(applies, prop), do: merge_prop(applies, prop)

  @doc "卸下时从 applies 扣减 prop（LPC unequip 反向累减）"
  def unequip_state(applies, prop), do: subtract_prop(applies, prop)

  @doc "护甲合并（armor + prop）到 applies"
  def wear_state(applies, armor, prop) do
    applies
    |> merge_prop(prop)
    |> Map.update(:armor, armor || 0, &(&1 + (armor || 0)))
  end

  # ---- internal ----

  defp merge_prop(applies, nil), do: applies

  defp merge_prop(applies, prop) when is_map(prop) do
    Enum.reduce(prop, applies, fn {key, val}, acc ->
      Map.update(acc, key, val, &(&1 + val))
    end)
  end

  defp merge_prop(applies, _), do: applies

  defp subtract_prop(applies, nil), do: applies

  defp subtract_prop(applies, prop) when is_map(prop) do
    Enum.reduce(prop, applies, fn {key, val}, acc ->
      Map.update(acc, key, -val, &(&1 - val))
    end)
  end

  defp subtract_prop(applies, _), do: applies
end
