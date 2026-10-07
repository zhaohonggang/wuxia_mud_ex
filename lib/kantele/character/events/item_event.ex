defmodule Kantele.Character.ItemEvent do
  use Kalevala.Character.Event

  require Logger

  alias Kantele.Character.CommandView
  alias Kantele.Character.ItemView
  alias Kantele.World.Items

  def drop_abort(conn, %{data: %{reason: :no_item, item_name: item_name}}) do
    conn
    |> assign(:item_name, item_name)
    |> render(ItemView, "unknown")
    |> prompt(CommandView, "prompt")
  end

  def drop_abort(conn, %{data: event}) do
    %{item_instance: item_instance, reason: reason} = event

    item = Items.get!(item_instance.item_id)

    conn
    |> assign(:item, item)
    |> assign(:reason, reason)
    |> render(ItemView, "drop-abort")
    |> prompt(CommandView, "prompt")
  end

  def drop_commit(conn, %{data: event}) do
    inventory =
      Enum.reject(conn.character.inventory, fn item_instance ->
        event.item_instance.id == item_instance.id
      end)

    item_instance = with_item(event.item_instance)
    item = item_instance.item

    conn
    |> put_character(%{conn.character | inventory: inventory})
    |> render(ItemView, "drop-commit", %{item: item, item_instance: item_instance})
    |> prompt(CommandView, "prompt")
  end

  def pickup_abort(conn, %{data: %{reason: :no_item, item_name: item_name}}) do
    conn
    |> assign(:item_name, item_name)
    |> render(ItemView, "unknown")
    |> prompt(CommandView, "prompt")
  end

  def pickup_abort(conn, %{data: event}) do
    %{item_instance: item_instance, reason: reason} = event

    item = Items.get!(item_instance.item_id)

    conn
    |> assign(:item, item)
    |> assign(:reason, reason)
    |> render(ItemView, "pickup-abort", event)
    |> prompt(CommandView, "prompt")
  end

  def pickup_commit(conn, %{data: event}) do
    inventory = [event.item_instance | conn.character.inventory]

    item_instance = with_item(event.item_instance)
    item = item_instance.item

    conn
    |> put_character(%{conn.character | inventory: inventory})
    |> render(ItemView, "pickup-commit", %{item: item, item_instance: item_instance})
    |> prompt(CommandView, "prompt")
    |> tap_save()
  end

  def hide_commit(conn, %{data: event}) do
    inventory =
      Enum.reject(conn.character.inventory, fn item_instance ->
        event.item_instance.id == item_instance.id
      end)

    item_instance = with_item(event.item_instance)
    item = item_instance.item

    conn
    |> put_character(%{conn.character | inventory: inventory})
    |> render(ItemView, "hide-commit", %{item: item, item_instance: item_instance})
    |> prompt(CommandView, "prompt")
    |> tap_save()
  end

  # 实例已挂真实定义（wuji 书册的随机标题副本）时保留，否则回填世界定义
  defp with_item(%{item: %Kalevala.World.Item{} = item} = item_instance)
       when not is_nil(item.id) do
    item_instance
  end

  defp with_item(item_instance) do
    %{item_instance | item: Items.get!(item_instance.item_id)}
  end

  defp tap_save(conn) do
    Kantele.Character.Records.save(current_character(conn))
    conn
  end

  defp current_character(conn), do: conn.private.update_character || conn.character
end
