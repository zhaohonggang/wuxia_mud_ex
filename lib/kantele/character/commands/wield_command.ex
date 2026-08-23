defmodule Kantele.Character.WieldCommand do
  @moduledoc """
  装备命令：`wield <武器>` / `wear <护甲>` / `unwield <武器>` / `remove <护甲>`

  装备快照写入 `meta.combat.equipped`，命中管线据此结算
  武器伤害与护甲减免。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.Combat
  alias Kantele.Character.CommandView
  alias Kantele.World.Items

  def wield(conn, params), do: equip(conn, params, :weapon)

  def wear(conn, params), do: equip(conn, params, :armor)

  def unwield(conn, params), do: unequip(conn, params, :weapon)

  def remove(conn, params), do: unequip(conn, params, :armor)

  defp equip(conn, %{"item_name" => item_name}, slot) do
    character = conn.character
    item_instance = find_instance(character.inventory, item_name)

    case item_instance && Items.get!(item_instance.item_id) do
      nil ->
        render_error(conn, "你的身上没有这样东西。\n")

      item ->
        value =
          case slot do
            :weapon -> Map.get(item.meta, :damage)
            :armor -> Map.get(item.meta, :armor)
          end

        cond do
          is_nil(value) or value <= 0 ->
            render_error(conn, "#{item.name}不能这样装备。\n")

          true ->
            snapshot =
              case slot do
                :weapon -> %{name: item.name, skill_type: Map.get(item.meta, :skill_type, "sword"), damage: value}
                :armor -> %{name: item.name, armor: value}
              end

            combat =
              character.meta.combat
              |> Combat.unequip(slot)
              |> Combat.equip(slot, snapshot)

            verb =
              case slot do
                :weapon -> "你「唰」的一声抽出一柄#{item.name}握在手中。\n"
                :armor -> "你穿上了一件#{item.name}。\n"
              end

            conn
            |> put_character(%{character | meta: %{character.meta | combat: combat}})
            |> render(CommandView, "text", %{text: verb})
            |> prompt(CommandView, "prompt", %{})
        end
    end
  end

  defp unequip(conn, %{"item_name" => item_name}, slot) do
    character = conn.character
    item_instance = find_instance(character.inventory, item_name)

    equipped_meta =
      case slot do
        :weapon -> Combat.weapon(character.meta.combat)
        :armor -> get_in(character.meta.combat.equipped, [:armor])
      end

    matches? =
      equipped_meta != nil and item_instance != nil and
        Map.get(equipped_meta, :name) == item_name(Items, item_instance.item_id)

    cond do
      not matches? ->
        render_error(conn, "你没有装备这样东西。\n")

      true ->
        combat = Combat.unequip(character.meta.combat, slot)

        conn
        |> put_character(%{character | meta: %{character.meta | combat: combat}})
        |> render(CommandView, "text", %{text: "你卸下了#{Map.get(equipped_meta, :name)}。\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  defp item_name(Items, item_id) do
    Items.get!(item_id).name
  rescue
    _ -> nil
  end

  defp find_instance(inventory, item_name) do
    Enum.find(inventory, fn item_instance ->
      item = Items.get!(item_instance.item_id)
      item_instance.id == item_name || item.callback_module.matches?(item, item_name)
    end)
  rescue
    _ -> nil
  end

  defp render_error(conn, message) do
    conn
    |> render(CommandView, "text", %{text: message})
    |> prompt(CommandView, "prompt", %{})
  end
end
