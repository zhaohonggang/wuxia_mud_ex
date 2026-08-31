defmodule Kantele.Character.ItemCommand do
  @moduledoc """
  物品命令：drop, get, put

  对应 LPC cmds/std/drop.c, get.c, put.c
  """

  use Kalevala.Character.Command

  alias Kalevala.Verb
  alias Kantele.Character.CommandView
  alias Kantele.Character.ItemView
  alias Kantele.World.Items

  @max_item_carried 80
  @max_item_in_room 999

  def drop(conn, %{"item_name" => item_name}) do
    character = conn.character

    cond do
      item_name == "all" ->
        drop_all(conn, character)

      true ->
        case find_item_instance(character.inventory, item_name) do
          nil ->
            render_error(conn, "你身上没有这样东西。\n")

          item_instance ->
            item = Items.get!(item_instance.item_id)
            drop_single(conn, character, item_instance, item)
        end
    end
  end

  def get(conn, %{"item_name" => item_name}) do
    character = conn.character

    cond do
      item_name == "all" ->
        get_all(conn, character)

      String.contains?(item_name, " from ") ->
        [item_part, container_part] = String.split(item_name, " from ", parts: 2)
        get_from_container(conn, character, String.trim(item_part), String.trim(container_part))

      true ->
        get_single(conn, character, item_name)
    end
  end

  def put(conn, %{"item" => item_name, "target" => target_name}) do
    character = conn.character

    case find_item_instance(character.inventory, item_name) do
      nil ->
        render_error(conn, "你身上没有这样东西。\n")

      item_instance ->
        item = Items.get!(item_instance.item_id)

        case find_container(character, target_name) do
          nil ->
            render_error(conn, "这里没有这样东西。\n")

          dest_instance ->
            dest = Items.get!(dest_instance.item_id)
            put_single(conn, character, item_instance, item, dest_instance, dest)
        end
    end
  end

  # ---- drop helpers ----

  defp drop_single(conn, character, item_instance, item) do
    combat = character.meta.combat

    cond do
      is_equipped?(combat, item_instance) ->
        render_error(conn, "#{item.name}必须脱下来才能丢掉。\n")

      is_riding?(character, item_instance) ->
        render_error(conn, "你正在骑乘这个东西，不能丢掉。\n")

      Map.get(item.meta || %{}, :no_drop) ->
        no_drop_msg = Map.get(item.meta, :no_drop)
        msg = if is_binary(no_drop_msg), do: no_drop_msg, else: "这样东西不能随意丢弃。\n"
        render_error(conn, msg)

      true ->
        conn
        |> request_item_drop(item_instance)
        |> assign(:prompt, false)
    end
  end

  defp drop_all(conn, character) do
    count =
      Enum.count(character.inventory, fn item_instance ->
        item = Items.get!(item_instance.item_id)
        combat = character.meta.combat

        !is_equipped?(combat, item_instance) &&
          !is_riding?(character, item_instance) &&
          !Map.get(item.meta || %{}, :no_drop)
      end)

    if count > 0 do
      character.inventory
      |> Enum.filter(fn item_instance ->
        item = Items.get!(item_instance.item_id)
        combat = character.meta.combat

        !is_equipped?(combat, item_instance) &&
          !is_riding?(character, item_instance) &&
          !Map.get(item.meta || %{}, :no_drop)
      end)
      |> Enum.each(fn item_instance ->
        request_item_drop(conn, item_instance)
      end)

      conn
      |> render(CommandView, "text", %{text: "你丢下了一堆东西。\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      render_error(conn, "你什么都没有丢掉。\n")
    end
  end

  # ---- get helpers ----

  defp get_single(conn, character, item_name) do
    room = conn.room

    case find_item_in_room(room, item_name) do
      nil ->
        render_error(conn, "你附近没有这样东西。\n")

      {item_instance, _item} ->
        get_item(conn, character, item_instance, item_name)
    end
  end

  defp get_from_container(conn, character, item_name, container_name) do
    room = conn.room

    container_instance =
      Enum.find(room.items ++ character.inventory, fn item_instance ->
        item = Items.get!(item_instance.item_id)
        item_instance.id == container_name || item.callback_module.matches?(item, container_name)
      end)

    case container_instance do
      nil ->
        render_error(conn, "你找不到 #{container_name} 这样东西。\n")

      _ ->
        container = Items.get!(container_instance.item_id)

        if Map.get(container.meta || %{}, :no_get_from) do
          render_error(conn, "你不能从这里拿东西。\n")
        else
          case find_item_in_container(container_instance, item_name) do
            nil ->
              render_error(conn, "这里没有这样东西。\n")

            {item_instance, _item} ->
              get_item(conn, character, item_instance, item_name)
          end
        end
    end
  end

  defp get_all(conn, character) do
    room = conn.room
    items = room.items

    if length(items) == 0 do
      render_error(conn, "你什么都没有拣起来。\n")
    else
      count =
        Enum.count(items, fn item_instance ->
          item = Items.get!(item_instance.item_id)

          !Map.get(item.meta || %{}, :no_get) &&
            length(character.inventory) < @max_item_carried
        end)

      if count > 0 do
        items
        |> Enum.filter(fn item_instance ->
          item = Items.get!(item_instance.item_id)

          !Map.get(item.meta || %{}, :no_get) &&
            length(character.inventory) < @max_item_carried
        end)
        |> Enum.each(fn item_instance ->
          request_item_pickup(conn, item_instance.id)
        end)

        conn
        |> render(CommandView, "text", %{text: "你把地上的东西都拣了起来。\n"})
        |> prompt(CommandView, "prompt", %{})
      else
        render_error(conn, "你什么都没有拣起来。\n")
      end
    end
  end

  defp get_item(conn, character, item_instance, item_name) do
    item = Items.get!(item_instance.item_id)

    cond do
      length(character.inventory) >= @max_item_carried ->
        render_error(conn, "你身上的东西实在是太多了，没法再拿东西了。\n")

      Map.get(item.meta || %{}, :no_get) ->
        no_get_msg = Map.get(item.meta, :no_get)
        msg = if is_binary(no_get_msg), do: no_get_msg, else: "这个东西拿不起来。\n"
        render_error(conn, msg)

      true ->
        conn
        |> request_item_pickup(item_instance.id)
        |> assign(:prompt, false)
    end
  end

  # ---- put helpers ----

  defp put_single(conn, character, item_instance, item, dest_instance, dest) do
    cond do
      Map.get(item.meta || %{}, :no_put) ->
        no_put_msg = Map.get(item.meta, :no_put)
        msg = if is_binary(no_put_msg), do: no_put_msg, else: "这个东西不要乱放。\n"
        render_error(conn, msg)

      Map.get(dest.meta || %{}, :no_get_from) ->
        render_error(conn, "还是不要打扰人家了。\n")

      Map.get(dest.meta || %{}, :is_depot) ->
        render_error(conn, "存东西到#{dest.name}的快捷方式：store 物品ID。\n")

      true ->
        conn
        |> request_item_drop(item_instance)
        |> assign(:prompt, false)
    end
  end

  # ---- equipment helpers ----

  defp is_equipped?(combat, item_instance) do
    Enum.any?(combat.equipped, fn {_slot, snap} ->
      Map.get(snap, :instance_id) == item_instance.id
    end)
  end

  defp is_riding?(character, item_instance) do
    riding = character.meta.riding
    riding && riding.id == item_instance.id
  end

  # ---- find helpers ----

  defp find_item_instance(inventory, item_name) do
    Enum.find(inventory, fn item_instance ->
      item = Items.get!(item_instance.item_id)
      item_instance.id == item_name || item.callback_module.matches?(item, item_name)
    end)
  rescue
    _ -> nil
  end

  defp find_item_in_room(room, item_name) do
    Enum.find_value(room.items, fn item_instance ->
      item = Items.get!(item_instance.item_id)

      if item_instance.id == item_name || item.callback_module.matches?(item, item_name) do
        {item_instance, item}
      else
        nil
      end
    end)
  rescue
    _ -> nil
  end

  defp find_item_in_container(container_instance, item_name) do
    container = Items.get!(container_instance.item_id)
    items = Map.get(container.meta || %{}, :items, [])

    Enum.find_value(items, fn item_instance ->
      item = Items.get!(item_instance.item_id)

      if item_instance.id == item_name || item.callback_module.matches?(item, item_name) do
        {item_instance, item}
      else
        nil
      end
    end)
  rescue
    _ -> nil
  end

  defp find_container(character, target_name) do
    Enum.find(character.inventory ++ character.room.items, fn item_instance ->
      item = Items.get!(item_instance.item_id)
      item_instance.id == target_name || item.callback_module.matches?(item, target_name)
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
