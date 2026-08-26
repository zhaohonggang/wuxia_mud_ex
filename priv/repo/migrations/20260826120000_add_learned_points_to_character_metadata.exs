defmodule Repo.Migrations.AddLearnedPointsToCharacterMetadata do
  use Ecto.Migration

  def change do
    alter table(:character_metadata) do
      add(:learned_points, :integer, default: 0)
    end
  end
end
