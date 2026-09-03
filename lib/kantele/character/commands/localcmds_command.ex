defmodule Kantele.Character.LocalcmdsCommand do
  @moduledoc """
  本地指令查询：`localcmds`

  对应 LPC cmds/wiz/localcmds.c。
  巫师专用，列出当前环境（房间）所提供的指令（即各方向出口）。
  """

  use Kalevala.Character.Command

  alias Kantele.Admin.Access
  alias Kantele.Character.CommandView
  alias Kantele.World.ZoneCache

  @direction_titles %{
    north: "北方",
    south: "南方",
    east: "东方",
    west: "西方",
    up: "上方",
    down: "下方"
  }

  def run(conn, _params) do
    character = conn.character

    unless Access.wizardp(character) do
      return_error(conn, "你没有巫师的权限。")
    end

    room_id = character.room_id

    case available_directions(room_id) do
      [] ->
        conn
        |> render(CommandView, "text", %{text: "你所在的房间没有任何可用的本地指令（出口）。\n"})
        |> prompt(CommandView, "prompt", %{})

      dirs ->
        lines = Enum.map_join(dirs, "\n", &(format_dir(&1)))

        conn
        |> render(CommandView, "text", %{
          text: "你所在的环境提供以下指令：\n#{lines}"
        })
        |> prompt(CommandView, "prompt", %{})
    end
  end

  defp format_dir(cmd) do
    title = Map.get(@direction_titles, String.to_atom(cmd), cmd)
    "#{String.pad_trailing(cmd, 15)}  前往#{title}\n"
  end

  # 根据 room_id 查 ZoneCache，抽出当前房间的出口方向
  defp available_directions(nil), do: []

  defp available_directions(room_id) when is_binary(room_id) do
    [zone_id, _room_key] = String.split(room_id, ":", parts: 2)

    case ZoneCache.get(zone_id) do
      {:ok, zone} ->
        room = Enum.find(Map.get(zone, :rooms, []), &(&1.id == room_id))

        (Map.get(room || %{}, :exits, []))
        |> Enum.map(fn exit -> exit.exit_name end)

      _ ->
        []
    end
  rescue
    _ -> []
  end

  defp return_error(conn, message) do
    conn
    |> render(CommandView, "text", %{text: message})
    |> prompt(CommandView, "prompt", %{})
  end
end