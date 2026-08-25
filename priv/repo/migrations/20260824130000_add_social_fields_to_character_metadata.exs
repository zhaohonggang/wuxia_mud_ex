defmodule ExVenture.Repo.Migrations.AddSocialFieldsToCharacterMetadata do
  use Ecto.Migration

  def change do
    alter table(:character_metadata) do
      add(:score, :integer, default: 0, null: false)
      add(:weiwang, :integer, default: 0, null: false)
      add(:gongxian, :integer, default: 0, null: false)
      add(:shen, :integer, default: 0, null: false)
      # 师徒/门派：%{"name" => "柳溪派", "master_id" => ..., "master_name" => ...}
      add(:family, :map, default: %{}, null: false)
    end
  end
end
