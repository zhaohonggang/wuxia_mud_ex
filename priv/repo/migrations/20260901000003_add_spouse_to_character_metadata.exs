defmodule ExVenture.Repo.Migrations.AddSpouseToCharacterMetadata do
  use Ecto.Migration

  def change do
    alter table(:character_metadata) do
      # spouse：配偶信息（S3 engage/accede/divorce.c）：%{"id" => ..., "name" => ...}
      add(:spouse, :map, default: %{})
    end
  end
end
