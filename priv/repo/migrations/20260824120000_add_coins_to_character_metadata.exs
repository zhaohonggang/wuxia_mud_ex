defmodule ExVenture.Repo.Migrations.AddCoinsToCharacterMetadata do
  use Ecto.Migration

  def change do
    alter table(:character_metadata) do
      add(:coins, :integer, default: 100, null: false)
    end
  end
end
