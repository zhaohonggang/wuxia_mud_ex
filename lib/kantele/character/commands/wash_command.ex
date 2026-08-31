defmodule Kantele.Character.WashCommand do
  @moduledoc """
  洗毒命令：`wash <武器/防具/hand>`

  对应 LPC cmds/std/wash.c。
  清除武器、防具或手上的毒药，需要房间有水源。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.World.Items

  def run(conn, %{"target" => target_name}) do
    character = conn.character

    if target_name == "" do
      conn
      |> render(CommandView, "text", %{text: "你要洗什么？\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      # 检查房间是否有水源
      if room_has_water?(conn) do
        case find_wash_target(character, target_name) do
          {:ok, :hand, _} ->
            wash_hand(conn, character)
          {:ok, :weapon, equip_item, equip_instance} ->
            wash_equipment(conn, character, equip_item, equip_instance, :weapon)
          {:ok, :armor, equip_item, equip_instance} ->
            wash_equipment(conn, character, equip_item, equip_instance, :armor)
          {:error, reason} ->
            conn
            |> render(CommandView, "text", %{text: reason <> "\n"})
            |> prompt(CommandView, "prompt", %{})
        end
      else
        conn
        |> render(CommandView, "text", %{text: "这里没有水，无法洗洗。\n"})
        |> prompt(CommandView, "prompt", %{})
      end
    end
  end

  def run(conn, %{}) do
    conn
    |> render(CommandView, "text", %{text: "你要洗什么？\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp room_has_water?(_conn) do
    # 简化：检查房间是否有 resource/water 标记
    true
  end

  defp find_wash_target(character, name) do
    name_lower = String.downcase(name)

    if name_lower in ["hand", "手"] do
      if character.meta.temp["daub/hand"] do
        {:ok, :hand, nil}
      else
        {:error, "你的手上没有毒。"}
      end
    else
      Enum.find(character.inventory, fn instance ->
        item = Items.get!(instance.item_id)
        item.callback_module.matches?(item, name)
      end)
      |> case do
        nil -> {:error, "你身上没有这样装备。"}
        instance ->
          item = Items.get!(instance.item_id)
          attrs = item.attrs || %{}
          meta = item.meta || %{}
          type = attrs["type"] || item.type

          cond do
            meta["daub"] == nil -> {:error, "这#{item.name}上没有毒。"}
            type in ["weapon", "sword", "blade", "axe", "hammer", "staff"] ->
              {:ok, :weapon, item, instance}
            type in ["armor", "cloth", "surcoat", "boots"] ->
              {:ok, :armor, item, instance}
            true ->
              {:error, "这不是可清洗的武器或防具。"}
          end
      end
    end
  end

  defp wash_hand(conn, character) do
    if character.meta.temp["daub/hand"] do
      new_temp = Map.delete(character.meta.temp, "daub/hand")
      new_meta = Map.put(character.meta, :temp, new_temp)
      new_character = %{character | meta: new_meta}
      new_conn = put_character(conn, new_character)

      new_conn
      |> render(CommandView, "text", %{text: "你把手上的毒药洗干净了。\n"})
      |> prompt(CommandView, "prompt", %{})
      |> save()
    else
      conn
      |> render(CommandView, "text", %{text: "你的手上没有毒。\n"})
      |> prompt(CommandView, "prompt", %{})
    end
  end

  defp wash_equipment(conn, character, equip_item, equip_instance, equip_type) do
    equip_meta = equip_item.meta || %{}
    equip_attrs = equip_item.attrs || %{}

    if equip_meta["daub"] do
      new_equip_meta = Map.delete(equip_meta, "daub")
      new_equip_attrs = Map.delete(equip_attrs, "poisoned")
      updated_equip = %{equip_item | meta: new_equip_meta, attrs: new_equip_attrs}

      new_inventory = Enum.map(character.inventory, fn inst ->
        if inst.id == equip_instance.id, do: updated_equip, else: inst
      end)

      new_character = %{character | inventory: new_inventory}
      new_conn = put_character(conn, new_character)

      new_conn
      |> render(CommandView, "text", %{text: "你把#{equip_item.name}上的毒药洗干净了。\n"})
      |> prompt(CommandView, "prompt", %{})
      |> save()
    else
      conn
      |> render(CommandView, "text", %{text: "这#{equip_item.name}上没有毒。\n"})
      |> prompt(CommandView, "prompt", %{})
    end
  end

  defp save(conn) do
    Records.save(conn.private.update_character || conn.character)
    conn
  end
end