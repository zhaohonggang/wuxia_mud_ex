defmodule ExVenture.Repo.Migrations.AddGuiltyToCharacterMetadata do
  use Ecto.Migration

  def up do
    alter table(:character_metadata) do
      # guilty: 戒律违犯计数（LPC query("guilty")；杀僧/食肉等破戒 +1，0=清净）。
      # 由 Kantele.Character.Precepts 写入，落盘后重登经 records.apply_to_character 恢复。
      add(:guilty, :integer, default: 0)
    end
  end

  def down do
    alter table(:character_metadata) do
      remove(:guilty)
    end
  end
end
