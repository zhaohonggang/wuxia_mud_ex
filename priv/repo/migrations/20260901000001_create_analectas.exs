defmodule Kantele.Repo.Migrations.CreateAnalectas do
  use Ecto.Migration

  def change do
    create table(:analectas) do
      add :year, :integer, null: false
      add :subject, :string, null: false
      add :author_name, :string, null: false
      add :author_id, :string, null: false
      add :content, :text, null: false
      add :board, :string, null: false
      add :time, :integer, null: false
      add :source_board, :string
      add :source_note_index, :integer

      timestamps()
    end

    create index(:analectas, [:year])
    create index(:analectas, [:author_id])
    create index(:analectas, [:time])
  end
end