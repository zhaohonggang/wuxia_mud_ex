defmodule Kantele.Item.Registry.UniqueItem do
  @moduledoc false
  use Ecto.Schema

  schema "unique_items" do
    field(:item_id, :string, primary_key: true)
    field(:item_template_id, :string)
    field(:holder_type, Ecto.Enum, values: [:player, :room, :npc])
    field(:holder_id, :string)
    field(:holder_pid, :string)

    timestamps()
  end
end