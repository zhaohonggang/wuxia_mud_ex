defmodule ExVenture.Repo.Migrations.AddBankCoinsToCharacterMetadata do
  use Ecto.Migration

  def change do
    alter table(:character_metadata) do
      add(:bank_coins, :integer, default: 0, null: false)
    end
  end
end
