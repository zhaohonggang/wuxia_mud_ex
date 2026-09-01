defmodule Kantele.Repo.Migrations.CreateNews do
  use Ecto.Migration

  def change do
    create table(:news) do
      add :title, :string, null: false
      add :author_name, :string, null: false
      add :author_id, :string, null: false
      add :content, :text, null: false
      add :time, :integer, null: false
      add :category, :string, default: "general"

      timestamps()
    end

    create index(:news, [:time])
    create index(:news, [:author_id])
    create index(:news, [:title])
  end
end