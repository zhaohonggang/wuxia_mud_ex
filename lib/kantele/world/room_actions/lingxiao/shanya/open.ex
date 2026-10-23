defmodule Kantele.World.RoomActions.Lingxiao.Shanya.Open do
  @moduledoc """
  `d/lingxiao/shanya.c` 的 `do_open`（`add_action("do_open", "open")`）。

  LPC 原文：

      int do_open(string arg)
      {
              if (! arg || arg != "bridge" )
                      return notify_fail("你要干嘛？\\n");

              message_vision(HIY "\\n$N" HIY "运足力气，大叫一声：“开门呀！”\\n" NOR,
                             this_player());

              message_vision(HIY "只听得城上有人说道：“有人来了，放吊桥吧。”\\n\\n" NOR
                             + HIC "只听得“轧轧轧”响了片刻，吊桥缓缓放下，露出一个"
                             "方方正正的城门来。\\n" NOR, this_player());

              set("exits/north", __DIR__"gate");
              remove_call_out("close");
              call_out("close", 10, this_object());

              return 1;
      }

      void close(object room)
      {
              message("vision", HIY "只听“嘎嘎嘎嘎”几声，吊桥又被关了起来。\\n" NOR, room);
              room->delete("exits/north");
      }

  ## 移植要点

  - **没有「已经开了」的守卫**：LPC 无条件 `set("exits/north", ...)`，所以反复
    `open bridge` 会反复放桥并重置 10 秒定时器（`remove_call_out` + `call_out`）。
    这里用 `DynamicExit.close_after/4` 的 `cancel_close` 语义复现同一行为。
  - 两句 `message_vision` → 两次 `broadcast_vision/4`（顺序保留，玩家先看到自己
    喊话、再看到城上回应）。
  - `close(room)` 的 `message("vision", ..., room)` 是**广播给房间所有人**（没有
    排除列表），`room->delete("exits/north")` 在播报**之后**执行 —— 顺序不影响
    可见结果，这里由 `DynamicExit.do_close_after/1` 一并完成（先 delete 再播报，
    因为 `delete` 不会改变在场玩家的输出顺序）。
  - `open` 是全局命令（`OpenCommand`，操作 `room.doors`）。`lingxiao:shanya` 的
    UCL 没有 `doors` 配置，所以这里的遮蔽不损失任何既有功能，且与 LPC
    `add_action` 优先级一致。
  """
  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.DynamicExit
  alias Kantele.World.RoomActions.Helpers

  @target_room "lingxiao:gate"
  @timer_key "exit_timer:close"
  @delay_ms 10_000

  @shout "\n$N运足力气，大叫一声：“开门呀！”\n"
  @answer "只听得城上有人说道：“有人来了，放吊桥吧。”\n\n" <>
            "只听得“轧轧轧”响了片刻，吊桥缓缓放下，露出一个方方正正的城门来。\n"
  @closed_message "只听“嘎嘎嘎嘎”几声，吊桥又被关了起来。\n"

  @impl true
  def run(conn, %{trailing: arg, room_id: room_id}) do
    if String.trim(arg) == "bridge" do
      conn
      |> Helpers.broadcast_vision(room_id, @shout)
      |> Helpers.broadcast_vision(room_id, @answer)
      |> open_bridge(room_id)
    else
      Helpers.render_to_player(conn, "你要干嘛？\n")
    end
  end

  defp open_bridge(conn, room_id) do
    DynamicExit.open(conn, room_id, "north", @target_room, "")

    DynamicExit.close_after(@delay_ms, room_id, @timer_key, [
      {room_id, "north", @closed_message}
    ])

    conn
  end
end
