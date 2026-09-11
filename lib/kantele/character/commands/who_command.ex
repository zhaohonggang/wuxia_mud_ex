defmodule Kantele.Character.WhoCommand do
  use Kalevala.Character.Command

  alias Kantele.Character.WhoView
  alias Kantele.Character.Presence

  def run(conn, _params) do
    characters =
      Presence.characters()
      |> Enum.reject(&Kantele.Bot.Registry.hidden?(&1.name))

    conn
    |> assign(:characters, characters)
    |> render(WhoView, "list")
  end
end
