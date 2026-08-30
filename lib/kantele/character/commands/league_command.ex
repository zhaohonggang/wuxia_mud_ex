defmodule Kantele.Character.LeagueCommand do
  @moduledoc """
  结社命令：`league`

  对应 LPC cmds/usr/league.c
  江湖结社系统。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, _params) do
    character = conn.character
    league = Map.get(character.meta, :league)

    if league do
      conn
      |> render(CommandView, "text", %{text: "你所属的结社：#{league}\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      conn
      |> render(CommandView, "text", %{text: "你还没有加入任何结社。\n"})
      |> prompt(CommandView, "prompt", %{})
    end
  end
end
