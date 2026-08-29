defmodule Kantele.House.House do
  @moduledoc false
  use Ecto.Schema

  schema "houses" do
    field(:owner_id, :string)
    field(:zone_id, :string)
    field(:room_spec, :map)
    field(:room_id, :string)
    field(:key_item_id, :string)
    field(:status, Ecto.Enum, values: [:pending, :approved, :built, :demolished])
    field(:approved_at, :utc_datetime)
    field(:approved_by, :string)

    timestamps()
  end
end