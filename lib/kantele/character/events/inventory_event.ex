defmodule Kantele.Character.InventoryEvent do
  use Kalevala.Character.Event

  alias Kantele.Character.InventoryView
  alias Kantele.World.Item, as: WorldItem

  def list(conn, _params) do
    # 不要用 Items.get!/1：背包是持久化数据，世界数据少一个定义就会
    # raise 掉整个 Foreman（见 WorldItem.fetch/1 的文档）
    item_instances = Enum.map(conn.character.inventory, &WorldItem.resolve/1)

    conn
    |> assign(:item_instances, item_instances)
    |> render(InventoryView, "list.event")
  end
end
