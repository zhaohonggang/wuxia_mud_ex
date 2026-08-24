defmodule Kantele.Character.InfoCommand do
  use Kalevala.Character.Command

  alias Kantele.Character.InfoView

  def run(conn, _params) do
    character = conn.character
    stats = character.meta.stats

    conn
    |> render(InfoView, "display", %{
      vitals: character.meta.vitals,
      str: stats.str,
      dex: stats.dex,
      con: stats.con,
      int: stats.int,
      combat_exp: stats.combat_exp,
      potential: stats.potential
    })
  end
end
