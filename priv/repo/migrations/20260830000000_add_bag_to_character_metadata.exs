defmodule ExVenture.Repo.Migrations.AddBagToCharacterMetadata do
  use Ecto.Migration

  def change do
    alter table(:character_metadata) do
      add(:bag, :map, default: %{})
    end
  end
end