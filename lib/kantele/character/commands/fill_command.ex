defmodule Kantele.Character.FillCommand do
  @moduledoc """
  装填液体：`fill <容器>`

  对应 LPC cmds/std/fill.c
  在有水的地方把容器装满清水。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.World.Items

  def run(conn, %{"item_name" => item_name}) do
    character = conn.character

    case find_container(character.inventory, item_name) do
      nil ->
        render_error(conn, "你身上没有这样东西。\n")

      instance ->
        item = Items.get!(instance.item_id)
        fill_container(conn, character, instance, item)
    end
  end

  defp fill_container(conn, character, instance, item) do
    meta = item.meta || %{}

    if Map.get(meta, :is_liquid_container) do
      new_meta = %{meta | liquid_type: "water", liquid_remaining: Map.get(meta, :max_liquid, 100)}

      conn
      |> render(CommandView, "text", %{text: "你将#{item.name}装满清水。\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      render_error(conn, "这个容器装不了水。\n")
    end
  end

  defp find_container(inventory, item_name) do
    Enum.find(inventory, fn instance ->
      item = Items.get!(instance.item_id)
      instance.id == item_name || item.callback_module.matches?(item, item_name)
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
