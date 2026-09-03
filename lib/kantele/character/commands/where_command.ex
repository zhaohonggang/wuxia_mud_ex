defmodule Kantele.Character.WhereCommand do
  use Kalevala.Character.Command

  alias Kantele.Admin.Access
  alias Kantele.Character.CommandView
  alias Kantele.Character.Presence

  def run(conn, _params) do
    character = conn.character

    unless Access.wizardp(character) do
      return_error(conn, "你没有巫师的权限。")
    end

    characters = Presence.characters()

    lines =
      characters
      |> Enum.group_by(& &1.room_id)
      |> Enum.map(fn {room_id, chars} ->
        names = Enum.map_join(chars, ", ", &"#{&1.name}(#{&1.id})")
        "#{room_id} : #{names}"
      end)
      |> Enum.join("\n")

    conn
    |> render(CommandView, "text", %{text: "在线角色位置:\n#{lines}\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp return_error(conn, message) do
    conn
    |> render(CommandView, "text", %{text: message})
    |> prompt(CommandView, "prompt", %{})
  end
end
