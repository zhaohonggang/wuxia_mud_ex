defmodule Kantele.World.Analecta do
  use Ecto.Schema
  import Ecto.Changeset

  schema "analectas" do
    field :year, :integer
    field :subject, :string
    field :author_name, :string
    field :author_id, :string
    field :content, :string
    field :board, :string
    field :time, :integer
    field :source_board, :string
    field :source_note_index, :integer

    timestamps()
  end

  def changeset(analecta, attrs) do
    analecta
    |> cast(attrs, [:year, :subject, :author_name, :author_id, :content, :board, :time, :source_board, :source_note_index])
    |> validate_required([:year, :subject, :author_name, :author_id, :content, :board, :time])
  end
end