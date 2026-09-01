defmodule Kantele.World.News do
  use Ecto.Schema
  import Ecto.Changeset

  schema "news" do
    field :title, :string
    field :author_name, :string
    field :author_id, :string
    field :content, :string
    field :time, :integer
    field :category, :string

    timestamps()
  end

  def changeset(news, attrs) do
    news
    |> cast(attrs, [:title, :author_name, :author_id, :content, :time, :category])
    |> validate_required([:title, :author_name, :author_id, :content, :time])
  end
end