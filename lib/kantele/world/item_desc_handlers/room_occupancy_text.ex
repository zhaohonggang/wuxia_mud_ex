defmodule Kantele.World.ItemDescHandlers.RoomOccupancyText do
  @moduledoc """
  数据驱动动态 `item_desc`：按目标房间是否有人选择文本（P5-4f）。

  LPC 常见形式：

      string look_men()
      {
          object room = load_object(__DIR__"xiuxishi");
          if (room->query_temp("person_inside") > 0)
              return "门上挂了个牌子：休息中、请毋打扰\\n";
          return "门上挂了个牌子：休息室\\n";
      }

  UCL 示例：

      item_desc = {
       men = {
        kind = "room_occupancy"
        room_id = "guanwai:xiuxishi"
        hidden = "门上挂了个牌子：休息室"
        shown = "门上挂了个牌子：休息中、请毋打扰"
       }
      }

  Elixir 侧没有 LPC `person_inside` 计数器，直接用目标房间进程的角色快照判断
  占用；房间未启动时视为无人。`shown` 表示有人，`hidden` 表示无人。
  """

  import Kalevala.World.Room.Context

  alias Kantele.Character.CommandView
  alias Kantele.World.Room

  @default_text "这里没有这个东西。\n"

  def run(context, requester, %{config: config} = params) do
    room_id = Map.get(config, "room_id") || Map.get(params, :room_id)
    current_room_id = Map.get(params, :room_id)

    text =
      if occupied?(context, room_id, current_room_id) do
        Map.get(config, "shown") || Map.get(config, "hidden") || @default_text
      else
        Map.get(config, "hidden") || @default_text
      end

    render(context, requester.pid, CommandView, "text", %{text: ensure_newline(text)})
  end

  # 当前房间在房间进程内执行，直接读 context.characters；跨房间才查目标快照。
  defp occupied?(context, room_id, current_room_id) when room_id == current_room_id do
    is_list(context.characters) and context.characters != []
  end

  defp occupied?(_context, room_id, _current_room_id) when is_binary(room_id) do
    case Room.snapshot(room_id) do
      %{private: %{characters: characters}} when is_list(characters) -> characters != []
      _ -> false
    end
  end

  defp occupied?(_context, _room_id, _current_room_id), do: false

  defp ensure_newline(text) when is_binary(text), do: String.trim_trailing(text) <> "\n"
  defp ensure_newline(_text), do: @default_text
end
