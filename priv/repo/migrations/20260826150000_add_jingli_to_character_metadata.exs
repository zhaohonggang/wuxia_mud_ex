defmodule Repo.Migrations.AddJingliToCharacterMetadata do
  use Ecto.Migration

  def change do
    alter table(:character_metadata) do
      add(:max_jingli, :integer, default: 0)
    end
  end
end
