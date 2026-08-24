defmodule ExVenture.Repo.Migrations.AddInventoryToCharacterMetadata do
  use Ecto.Migration

  def change do
    alter table(:character_metadata) do
      add(:inventory, {:array, :map}, default: [], null: false)
      add(:equipment, :map, default: %{}, null: false)
    end
  end
end
