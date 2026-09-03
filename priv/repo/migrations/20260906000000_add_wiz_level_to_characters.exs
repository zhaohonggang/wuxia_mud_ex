defmodule ExVenture.Repo.Migrations.AddWizLevelToCharacters do
  use Ecto.Migration

  def change do
    alter table(:characters) do
      add(:wiz_level, :integer, default: 0, null: false)
    end
  end
end
