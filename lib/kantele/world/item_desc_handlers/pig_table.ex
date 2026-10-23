defmodule Kantele.World.ItemDescHandlers.PigTable do
  @moduledoc """
  数据驱动动态 `item_desc`：拱猪牌桌 / 成绩表（`look table` / `look scoreboard`）。

  对应 LPC `d/city/eproom.c`（nproom/sproom/wproom 同源）：

      string look_table()
      {
          if (this_player()->query_temp("pigging_seat"))
              return table_str(this_player()->query_temp("pigging_seat"));
          return table_str("");
      }

      string look_scoreboard() { return scoreboard_str(); }

  渲染全部委托给 `Kantele.World.PigGame`（`table_str/2` / `scoreboard_str/1`），
  本模块只负责「从房间 state 里取出牌局 + 从角色 temp 里取出观察者座位」。

  ## 状态位置

  - 牌局：房间 `state["pig_game"]`（`Room.put_state_by_id/3` 写入，仅内存）。
    读的时候直接取 `context.data.state`，不必跨进程调用房间。
  - 观察者座位：角色 `meta.temp["pigging_seat"]`（`Kantele.Character.PigEvent`
    与 `RoomActions.City.PigRoom` 维护）。未入座 → `""`，与 LPC `table_str("")`
    一致（此时按北家视角渲染）。

  房间进程重启 / 首次进房时 `state["pig_game"]` 不存在，回落到 `PigGame.new/0`
  （空桌视图），不会报错。

  UCL 示例：

      item_desc = {
       table = { kind = "pig_table" }
       scoreboard = { kind = "pig_scoreboard" }
      }
  """

  import Kalevala.World.Room.Context

  alias Kantele.Character.CommandView
  alias Kantele.World.PigGame

  @default_text "这里没有这个东西。\n"

  def run(context, requester, _params) do
    text = context |> game() |> PigGame.table_str(viewer_seat(requester))
    render(context, requester.pid, CommandView, "text", %{text: ensure_newline(text)})
  end

  def run_scoreboard(context, requester, _params) do
    text = context |> game() |> PigGame.scoreboard_str()
    render(context, requester.pid, CommandView, "text", %{text: ensure_newline(text)})
  end

  # 房间 state 里的牌局；缺失/类型不对时给一局全新的空桌。
  defp game(context) do
    state = Map.get(context.data, :state, %{}) || %{}

    case Map.get(state, "pig_game") do
      %{stage: _} = game -> game
      _ -> PigGame.new()
    end
  end

  # 观察者座位：来自角色 temp `pigging_seat`；未坐则为 ""（对应 LPC table_str("")）。
  defp viewer_seat(requester) do
    temp = Map.get(Map.get(requester, :meta, %{}), :temp, %{}) || %{}

    case Map.get(temp, "pigging_seat") do
      s when is_binary(s) and s != "" -> s
      _ -> ""
    end
  end

  defp ensure_newline(text) when is_binary(text), do: String.trim_trailing(text) <> "\n"
  defp ensure_newline(_text), do: @default_text
end
