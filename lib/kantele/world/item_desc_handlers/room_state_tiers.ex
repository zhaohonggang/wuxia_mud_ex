defmodule Kantele.World.ItemDescHandlers.RoomStateTiers do
  @moduledoc """
  数据驱动动态 `item_desc`：按房间 state 的**多个键**选择文本（P5-4h）。

  对应 LPC 这种「先看机关状态、再看某个计数」的多段分支：

      string look_hole()
      {
          if (query("status") != 4) return "哪里有什么洞？抓老鼠么？\\n";
          if (query("book_count"))
              return "这是铜镜下面的一个小洞，里面放着一本残破的旧经书(book)。\\n";
          return "这是铜镜下面的一个小洞，里面空空如也，什么也没有。\\n";
      }

  UCL 示例：

      item_desc = {
       hole = {
        kind = "room_state_tiers"
        tiers = [
         { match = { status = 4  book_count = 1 }
           text = "这是铜镜下面的一个小洞，里面放着一本残破的旧经书(book)。" },
         { match = { status = 4  book_count = 0 }
           text = "这是铜镜下面的一个小洞，里面空空如也，什么也没有。" },
         { text = "哪里有什么洞？抓老鼠么？" }
        ]
       }
      }

  ## 匹配规则

  **按顺序**取第一个 `match` 全部命中的层级：

  - `match` 的每个键值对都要求房间 state 里的同名键**精确相等**（`4 == 4`、
    `0 == 0`）；缺键（`nil`）不算命中 —— 所以 `{ status = 4 }` 不会误命中
    「还没掀开过」的房间。
  - **没有 `match`**（或 `match` 为空表）的层级是兜底项，恒命中，须放在最后。
  - 一个层级都没有命中时回落「这里没有这个东西。」。

  与 `room_temp`（单个键的「有/无」两分支）相比，本 handler 用于**两个维度**
  （开合状态 + 是否还有东西）共同决定文案的场景。

  `room_id` 省略时取当前房间；读取别的房间时显式写 `room_id = "zone:room"`。
  """

  import Kalevala.World.Room.Context

  alias Kantele.Character.CommandView
  alias Kantele.World.Room

  @default_text "这里没有这个东西。\n"

  def run(context, requester, %{config: config} = params) do
    room_id = Map.get(config, "room_id") || Map.get(params, :room_id)
    current_room_id = Map.get(params, :room_id)

    text =
      Map.get(config, "tiers")
      |> select_tier(context, room_id, current_room_id)
      |> case do
        nil -> @default_text
        tier -> Map.get(tier, "text") || @default_text
      end

    render(context, requester.pid, CommandView, "text", %{text: ensure_newline(text)})
  end

  defp select_tier(tiers, context, room_id, current_room_id) when is_list(tiers) do
    Enum.find(tiers, fn tier ->
      tier
      |> Map.get("match")
      |> match_all?(context, room_id, current_room_id)
    end)
  end

  defp select_tier(_tiers, _context, _room_id, _current_room_id), do: nil

  defp match_all?(match, context, room_id, current_room_id)
       when is_map(match) and map_size(match) > 0 do
    Enum.all?(match, fn {key, expected} ->
      state_value(context, room_id, current_room_id, key) == expected
    end)
  end

  # 无 match（nil / 空表）= 兜底项
  defp match_all?(_match, _context, _room_id, _current_room_id), do: true

  # 当前房间的 handler 在房间进程内执行，不能对自己 `:sys.get_state/1`；
  # 直接用本次 context 里的房间数据。跨房间才查询目标房间进程。
  defp state_value(context, room_id, current_room_id, key) when is_binary(key) do
    if room_id == current_room_id do
      Map.get(Map.get(context.data, :state, %{}) || %{}, key)
    else
      Room.get_state_by_id(room_id, key)
    end
  end

  defp state_value(_context, _room_id, _current_room_id, _key), do: nil

  defp ensure_newline(text) when is_binary(text), do: String.trim_trailing(text) <> "\n"
  defp ensure_newline(_text), do: @default_text
end
