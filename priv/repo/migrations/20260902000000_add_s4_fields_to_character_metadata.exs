defmodule ExVenture.Repo.Migrations.AddS4FieldsToCharacterMetadata do
  use Ecto.Migration

  def change do
    alter table(:character_metadata) do
      # schedule：个人计划（S4 scheme.c）
      add(:schedule, :string)
      # tianshu_books：天书已完成表（S4 tianshu.c）：%{"书名" => 1}
      add(:tianshu_books, :map, default: %{})
      # jifen：积分（S4 jifen.c）
      add(:jifen, :integer, default: 0)
    end
  end
end
