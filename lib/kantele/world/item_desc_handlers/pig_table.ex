defmodule Kantele.World.ItemDescHandlers.PigTable do
  @moduledoc """
  数据驱动动态 `item_desc`：拱猪牌桌显示（look_table）。

  对应 LPC `inherit PIG_ROOM` / `d/city/eproom.c`（nproom/sproom/wproom 同源）的
  `look_table()`：

      string look_table()
      {
          if (this_player()->query_temp("pigging_seat"))
              return table_str(this_player()->query_temp("pigging_seat"));
          return table_str("");
      }

  玩家坐席记在角色 temp `pigging_seat`（座位名："north"/"west"/"south"/"east"，未坐则为空）；
  房间牌局状态记在 `Room.state`（UCL `state` 播种）。handler 只负责 `look_table` 渲染，
  不承担坐下/发牌/叫牌/出牌等动作（后续子系统接线时再扩展）。

  UCL 示例：

      item_desc = {
       table = { kind = "pig_table" }
      }
      state = {
        pig_phase = "initting"
        pig_pl = { north = nil west = nil south = nil east = nil }
        pig_server = ""
      }

  非游戏中或未满四人时，输出“这是一张专门用于拱猪的四方桌。”及各座位状态：
  空位提示「想玩可用 sit X 坐上去」；已坐则显示玩家名，桌长标注「(桌长)」。
  """

  import Kalevala.World.Room.Context

  alias Kantele.Character.CommandView

  @default_text "这里没有这个东西。\n"

  @seats ["north", "west", "south", "east"]

  @chinese_seat %{
    "north" => "北边",
    "west" => "西边",
    "south" => "南边",
    "east" => "东边"
  }

  def run(context, requester, _params) do
    text = render_text(context, requester)
    render(context, requester.pid, CommandView, "text", %{text: ensure_newline(text)})
  end

  defp render_text(context, requester) do
    seat = viewer_seat(requester)
    state = Map.get(context.data, :state, %{}) || %{}
    phase = Map.get(state, "pig_phase", "initting")
    pl = pig_pl(state)
    server = Map.get(state, "pig_server", "")

    cond do
      phase == "playing" and seated_count(pl) == 4 ->
        render_playing(state, seat, pl, server)
      true ->
        render_seats(pl, server)
    end
  end

  # 观察者所在座位：来自角色 temp `pigging_seat`；未坐则为 ""（对应 LPC table_str("")）。
  defp viewer_seat(requester) do
    temp = Map.get(Map.get(requester, :meta, %{}), :temp, %{}) || %{}
    case Map.get(temp, "pigging_seat") do
      nil -> ""
      s when is_binary(s) and s != "" -> s
      _ -> ""
    end
  end

  # 从 string-keyed state 取出 pig_pl，缺失时全部空位。
  defp pig_pl(state) do
    Map.get(state, "pig_pl", %{
      "north" => nil, "west" => nil, "south" => nil, "east" => nil
    })
  end

  defp seated_count(pl) when is_map(pl) do
    pl
    |> Map.values()
    |> Enum.filter(&(&1 != nil and &1 != ""))
    |> length()
  end

  # ---- 非游戏中 / 未满四人：座位状态视图（对应 LPC table_str 的 else 分支） ----

  defp render_seats(pl, server) do
    status =
      Enum.reduce(@seats, "", fn seat, acc ->
        cond do
          seat_empty?(pl, seat) ->
            acc <> seat_empty_line(seat)

          player_of(pl, seat) == server ->
            acc <> seat_taken_line(seat, player_of(pl, seat), true)

          true ->
            acc <> seat_taken_line(seat, player_of(pl, seat), false)
        end
      end)

    "这是一张专门用于拱猪的四方桌。\n" <> status
  end

  defp seat_empty?(pl, seat) do
    case Map.get(pl, seat) do
      nil -> true
      "" -> true
      _ -> false
    end
  end

  defp seat_empty_line(seat) do
    "#{@chinese_seat[seat]}的椅子是空的。 想玩可用 sit #{seat} 坐上去。\n"
  end

  defp seat_taken_line(seat, name, is_server) do
    suffix = if is_server, do: "(桌长)", else: ""
    "#{@chinese_seat[seat]}的椅子上坐的是：#{name}#{suffix}。\n"
  end

  # ---- 游戏中且四人齐：牌桌视图（对应 LPC table_str 的 playing 分支，骨架） ----

  defp render_playing(_state, _seat, _pl, _server) do
    # 待牌局状态机接线后完整实现；当前按座位状态兜底，避免空房间报错。
    # TODO: 接入 roundcards / round_order / bidcard_str 等，渲染出牌行与手牌。
    render_seats(%{
      "north" => nil, "west" => nil, "south" => nil, "east" => nil
    }, "")
  end

  defp ensure_newline(text) when is_binary(text), do: String.trim_trailing(text) <> "\n"
  defp ensure_newline(_text), do: @default_text
end
