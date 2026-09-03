defmodule Kantele.Character.HomeCommand do
  @moduledoc """
  回家命令：`home`

  对应 LPC cmds/wiz/home.c。
  巫师专用，直接回到所属区域的起始房间（此实现回退到区域起始房间）。
  """

  use Kalevala.Character.Command

  alias Kantele.Admin.Access
  alias Kantele.Character.CommandView
  alias Kantele.Character.Teleport
  alias Kantele.World.ZoneCache

  def run(conn, _params) do
    character = conn.character

    case Access.wizardp(character) do
      false ->
        return_error(conn, "你没有巫师的权限。")

      true ->
        room_id = character.room_id

        case start_room_id(room_id) do
          nil ->
            conn
            |> render(CommandView, "text", %{text: "当前区域无法使用 home 指令。\n"})
            |> prompt(CommandView, "prompt", %{})

          dest when dest == room_id ->
            conn
            |> render(CommandView, "text", %{text: "你已经在起始之地了。\n"})
            |> prompt(CommandView, "prompt", %{})

          dest ->
            conn
            |> Teleport.teleport(dest)
        end
    end
  end

  # 由 room_id 取 zone_id，再通过 ZoneCache 找该区域的起始房间 id
  defp start_room_id(nil), do: nil

  defp start_room_id(room_id) when is_binary(room_id) do
    zone_id = room_id |> String.split(":", parts: 2) |> hd()

    case ZoneCache.get(zone_id) do
      {:ok, zone} ->
        rooms = Map.get(zone, :rooms, [])

        case Enum.find(rooms, fn room -> "startroom" in (room.flags || []) end) do
          nil ->
            case Enum.at(rooms, 0) do
              nil -> nil
              first -> first.id
            end

          start ->
            start.id
        end

      _ ->
        nil
    end
  rescue
    _ -> nil
  end

  defp return_error(conn, message) do
    conn
    |> render(CommandView, "text", %{text: message})
    |> prompt(CommandView, "prompt", %{})
  end
end