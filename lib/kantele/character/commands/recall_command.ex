defmodule Kantele.Character.RecallCommand do
  @moduledoc """
  回城命令：`recall`（cmds/usr/recall.c）

  把玩家传送回当前区域（zone）的起始房间。起始房间按 `startroom` flag 识别，
  无则回退到区域房间列表的第一个；已身在该房间时提示无需回城。

  参考实现用 LPC 坐标在地图上定点，Kantele 改用"区域起始房间"映射。
  运行态角色 room_id 形如 `zone:key`，取其 zone 前缀查 ZoneCache。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Teleport
  alias Kantele.World.ZoneCache

  def run(conn, _params) do
    character = conn.character
    room_id = character.room_id

    case start_room_id(room_id) do
      nil ->
        conn
        |> render(CommandView, "text", %{text: "当前区域无法使用 recall 指令。\n"})
        |> prompt(CommandView, "prompt", %{})

      dest when dest == room_id ->
        conn
        |> render(CommandView, "text", %{text: "你已经在起始之地了。\n"})
        |> prompt(CommandView, "prompt", %{})

      dest ->
        conn
        |> Teleport.teleport(dest)
        |> assign(:prompt, false)
    end
  end

  # 从 room_id 取 zone_id，再从 ZoneCache 找该区域的起始房间 id
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
end
