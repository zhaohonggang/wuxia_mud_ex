defmodule ExVenture.Repo.Migrations.CreateCharacterMetadata do
  use Ecto.Migration

  def change do
    create table(:character_metadata) do
      add(:character_id, references(:characters), null: false)
      add(:str, :integer, default: 20, null: false)
      add(:dex, :integer, default: 20, null: false)
      add(:con, :integer, default: 20, null: false)
      add(:int, :integer, default: 20, null: false)
      add(:combat_exp, :integer, default: 0, null: false)
      add(:potential, :integer, default: 100, null: false)
      add(:max_neili, :integer, default: 200, null: false)
      add(:skills, :map, default: %{}, null: false)
      add(:mapped, :map, default: %{}, null: false)
      add(:performs, {:array, :string}, default: [], null: false)

      timestamps()
    end

    create(unique_index(:character_metadata, [:character_id]))
  end
end
