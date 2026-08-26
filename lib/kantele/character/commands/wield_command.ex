defmodule Kantele.Character.WieldCommand do
  @moduledoc """
  装备命令：`wield <武器>` / `wear <护甲>` / `unwield <武器>` / `remove <护甲>`

  b6/B4 多槽位：wear 按物品的 armor_type 决定槽位
  （cloth/head/feet/waist/...，同槽互斥），不同槽位可同时穿戴。
  快照写入 `meta.combat.equipped`，命中管线据此结算武器伤害、
  护甲减免与多键 prop 加成。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.Combat
  alias Kantele.Character.CommandView
  alias Kantele.World.Item.Meta
  alias Kantele.World.Items

  def wield(conn, params) do
    equip_weapon(conn, params)
  end

  def wear(conn, params) do
    equip_armor(conn, params)
  end

  def unwield(conn, %{"item_name" => item_name} = _params) do
    character = conn.character
    weapon_snap = Combat.weapon(character.meta.combat)

    cond do
      weapon_snap != nil && snapshot_matches?(weapon_snap, item_name) ->
        combat = Combat.unequip(character.meta.combat, :weapon)

        conn
        |> put_character(%{character | meta: %{character.meta | combat: combat}})
        |> render(CommandView, "text", %{text: "你卸下了#{Map.get(weapon_snap, :name)}。\n"})
        |> prompt(CommandView, "prompt", %{})

      true ->
        render_error(conn, "你没有装备这样东西。\n")
    end
  end

  def remove(conn, %{"item_name" => item_name} = _params) do
    character = conn.character

    slot =
      Enum.find_value(character.meta.combat.equipped, fn
        {:weapon, _snap} -> nil
        {slot, snap} -> if snapshot_matches?(snap, item_name), do: slot
      end)

    case slot do
      nil ->
        render_error(conn, "你没有装备这样东西。\n")

      slot ->
        snap = get_in(character.meta.combat.equipped, [slot])
        combat = Combat.unequip(character.meta.combat, slot)

        conn
        |> put_character(%{character | meta: %{character.meta | combat: combat}})
        |> render(CommandView, "text", %{text: "你卸下了#{Map.get(snap, :name)}。\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  # ---- 武器 ----

  defp equip_weapon(conn, %{"item_name" => item_name}) do
    character = conn.character

    with_item(conn, character, item_name, fn item ->
      damage = Map.get(item.meta, :damage)

      cond do
        is_nil(damage) or damage <= 0 ->
          render_error(conn, "#{item.name}不能这样装备。\n")

        true ->
          snapshot = %{
            name: item.name,
            skill_type: Map.get(item.meta, :skill_type, "sword"),
            damage: damage,
            prop: Map.get(item.meta, :weapon_prop)
          }

          combat =
            character.meta.combat
            |> Combat.unequip(:weapon)
            |> Combat.equip(:weapon, snapshot)

          conn
          |> put_character(%{character | meta: %{character.meta | combat: combat}})
          |> render(CommandView, "text", %{text: "你「唰」的一声抽出一柄#{item.name}握在手中。\n"})
          |> prompt(CommandView, "prompt", %{})
      end
    end)
  end

  # ---- 护甲（按 armor_type 槽位） ----

  defp equip_armor(conn, %{"item_name" => item_name}) do
    character = conn.character

    with_item(conn, character, item_name, fn item ->
      case armor_slot(item.meta) do
        nil ->
          render_error(conn, "#{item.name}不是可穿戴的护具。\n")

        slot ->
          if Combat.occupied?(character.meta.combat, slot) do
            render_error(conn, "你已经穿戴了同类型的护具了。\n")
          else
            snapshot = %{
              name: item.name,
              armor: Map.get(item.meta, :armor) || 0,
              prop: Map.get(item.meta, :armor_prop)
            }

            combat = Combat.equip(character.meta.combat, slot, snapshot)

            conn
            |> put_character(%{character | meta: %{character.meta | combat: combat}})
            |> render(CommandView, "text", %{text: "你穿上了一件#{item.name}。\n"})
            |> prompt(CommandView, "prompt", %{})
          end
      end
    end)
  end

  # 槽位白名单固定，字符串→原子安全；nil 表示不可穿戴
  defp armor_slot(meta) do
    case Meta.normalize_armor_type(Map.get(meta, :armor_type)) do
      nil -> nil
      slot -> String.to_atom(slot)
    end
  end

  # ---- 工具 ----

  defp with_item(conn, character, item_name, callback) do
    item_instance = find_instance(character.inventory, item_name)

    case item_instance && Items.get!(item_instance.item_id) do
      nil -> render_error(conn, "你的身上没有这样东西。\n")
      item -> callback.(item)
    end
  end

  # remove/unwield 支持中英文名匹配快照（快照存的是全名）
  defp snapshot_matches?(snapshot, item_name) do
    Kantele.World.Item.matches?(%{name: Map.get(snapshot, :name)}, item_name) or
      Map.get(snapshot, :name) == String.trim(item_name)
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
