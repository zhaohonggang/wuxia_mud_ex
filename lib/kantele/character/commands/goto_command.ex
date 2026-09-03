defmodule Kantele.Character.GotoCommand do
  use Kalevala.Character.Command

  alias Kantele.Admin.Access
  alias Kantele.Character.CommandView
  alias Kantele.Character.Teleport

  def run(conn, %{"target" => target}) do
    character = conn.character

    unless Access.wizardp(character) do
      return_error(conn, "你没有巫师的权限。")
    end

    case find_room(target) do
      nil ->
        return_error(conn, "找不到目标地点 #{target}。")

      room_id ->
        conn
        |> Teleport.teleport(room_id)
    end
  end

  def run(conn, _params) do
    character = conn.character

    unless Access.wizardp(character) do
      return_error(conn, "你没有巫师的权限。")
    end

    conn
    |> render(CommandView, "text", %{text: "用法: goto <房间ID或名称>\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp find_room(target) do
    characters = Kantele.Character.Presence.characters()

    target_lower = String.downcase(target)

    if char = Enum.find(characters, &(String.downcase(&1.name) == target_lower)) do
      char.room_id
    else
      if String.contains?(target, ":"), do: target, else: nil
    end
  end

  defp return_error(conn, message) do
    conn
    |> render(CommandView, "text", %{text: message})
    |> prompt(CommandView, "prompt", %{})
  end
end
