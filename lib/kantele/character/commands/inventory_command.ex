defmodule Kantele.Character.InventoryCommand do
  use Kalevala.Character.Command

  alias Kantele.Character.InventoryView
  alias Kantele.World.Item, as: WorldItem

  def run(conn, _params) do
    item_instances = Enum.map(conn.character.inventory, &WorldItem.resolve/1)

    conn
    |> assign(:item_instances, item_instances)
    |> render(InventoryView, "list")
  end
end
