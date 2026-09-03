defmodule Kantele.Character.Who1Command do
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
    count = length(characters)

    lines =
      Enum.map_join(characters, "\n", fn char ->
        wiz_level = Map.get(char.attributes, "wiz_level", 0)
        wiz_marker = if wiz_level > 0, do: "[W#{wiz_level}] ", else: ""
        "#{wiz_marker}#{char.name} - #{char.room_id}"
      end)

    conn
    |> render(CommandView, "text", %{text: "在线角色 (巫师模式):\n#{lines}\n共 #{count} 人。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp return_error(conn, message) do
    conn
    |> render(CommandView, "text", %{text: message})
    |> prompt(CommandView, "prompt", %{})
  end
end
