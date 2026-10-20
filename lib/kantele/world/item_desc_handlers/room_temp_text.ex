defmodule Kantele.World.ItemDescHandlers.RoomTempText do
  @moduledoc """
  数据驱动动态 `item_desc`：按房间 temp 状态选择文本（P5-4f）。

  LPC 常见形式：

      string look_net()
      {
          object here = find_object(__DIR__"furong1");
          if (here->query_temp("marks/拉"))
              return "一张被拉破的蜘蛛网悬在半空。\\n";
          return "你走进细看……\\n";
      }

  UCL 示例：

      item_desc = {
       net = {
        kind = "room_temp"
        key = "marks/拉"
        hidden = "你走进细看……"
        shown = "一张被拉破的蜘蛛网悬在半空。"
       }
      }

  `room_id` 省略时取当前房间（handler 参数）；需要读取别的房间时显式写
  `room_id = "zone:room"`（如 `look_men` 读取休息室占用状态）。
  """

  import Kalevala.World.Room.Context

  alias Kantele.Character.CommandView
  alias Kantele.World.Room

  @default_text "这里没有这个东西。\n"

  def run(context, requester, %{config: config} = params) do
    room_id = Map.get(config, "room_id") || Map.get(params, :room_id)
    current_room_id = Map.get(params, :room_id)
    key = Map.get(config, "key")

    text =
      if state_set?(context, room_id, current_room_id, key) do
        Map.get(config, "shown") || Map.get(config, "hidden") || @default_text
      else
        Map.get(config, "hidden") || @default_text
      end

    render(context, requester.pid, CommandView, "text", %{text: ensure_newline(text)})
  end

  # 当前房间的 handler 在房间进程内执行，不能对自己 `:sys.get_state/1`；
  # 直接用本次 context 里的房间数据。跨房间才查询目标房间进程。
  defp state_set?(context, room_id, current_room_id, key)
       when is_binary(room_id) and is_binary(key) do
    value =
      if room_id == current_room_id do
        Map.get(Map.get(context.data, :state, %{}) || %{}, key)
      else
        Room.get_state_by_id(room_id, key)
      end

    case value do
      nil -> false
      false -> false
      0 -> false
      "" -> false
      _ -> true
    end
  end

  defp state_set?(_context, _room_id, _current_room_id, _key), do: false

  defp ensure_newline(text) when is_binary(text), do: String.trim_trailing(text) <> "\n"
  defp ensure_newline(_text), do: @default_text
end
