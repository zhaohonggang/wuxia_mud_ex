defmodule Kantele.World.RoomActions.Lingxiao.Gate.Open do
  @moduledoc """
  `d/lingxiao/gate.c` 的 `do_open`（`add_action("do_open", "open")`）。

  LPC 原文：

      int do_open(string arg)
      {
              object room;

              if (query("exits/south"))
                      return notify_fail("吊桥已经放下来了。\\n");

              if (! arg || (arg != "bridge" && arg != "south"))
                      return notify_fail("你要开什么？\\n");

              if (! ( room = find_object(__DIR__"shanya")) )
                      room = load_object(__DIR__"shanya");
              if (objectp(room))
              {
                      set("exits/south", __DIR__"shanya");
                      message_vision(HIY "$N" HIY "让凌霄弟子把吊桥放了下来。\\n" NOR, this_player());
                      room->set("exits/north", __FILE__);
                      message("vision", HIY "只听“嘎嘎嘎嘎”几声，吊桥被放了下来。\\n" NOR, room);
                      remove_call_out("close_bridge");
                      call_out("close_bridge", 10);
              }

              return 1;
      }

  ## 与 `lingxiao:shanya` 的关系

  同一座吊桥的两端：`shanya` 的 `open bridge` 是**从崖下喊话**（那边 `set` 自己的
  `north`），这里是**从内门放桥**（`set` 自己的 `south` 并回填 `shanya` 的 `north`）。
  两处共用同一个 10 秒自动收桥语义，但各自是独立的 `call_out`（LPC 里函数名不同：
  `close` / `close_bridge`），所以 `timer_key` 也各自独立。

  ## 移植要点

  - **两处守卫的顺序与文案照抄**：先判「已经放下」，再判参数。参数接受
    `bridge` 与 `south` 两个别名（LPC 原样）。
  - 邻居房那句是 `message("vision", ..., room)`，说给**崖下**的人听，行动者不在那
    个房间，没有 `VisionView` 可渲染，所以用 `Room.tell_room/2` 发纯文本。
  - `remove_call_out("close_bridge")` + `call_out("close_bridge", 10)` →
    `DynamicExit.close_after/5`（同一 `timer_key` 只保留一个定时器）。
  - `close_bridge` **没有** `if (query("exits/south"))` 守卫，所以
    `only_if_open` 保持默认 `false`：即使出口已被 `close` 手动收掉，10 秒到点仍会
    再播一次「吊桥又被关了起来」。
  - `open` 是全局命令（`OpenCommand` 操作 `room.doors`）；本房 UCL 没有 `doors`
    配置，遮蔽不损失既有功能，且与 LPC `add_action` 优先级一致。
  """

  use Kantele.World.RoomAction

  alias Kantele.World.Room
  alias Kantele.World.RoomActions.DynamicExit
  alias Kantele.World.RoomActions.Helpers

  @neighbor_room "lingxiao:shanya"
  @self_room "lingxiao:gate"
  @timer_key "exit_timer:close_bridge"
  @delay_ms 10_000

  @args ["bridge", "south"]
  @opened "$N让凌霄弟子把吊桥放了下来。\n"
  @neighbor_opened "只听“嘎嘎嘎嘎”几声，吊桥被放了下来。\n"

  @impl true
  def run(conn, %{trailing: arg, room_id: room_id}) do
    arg = String.trim(arg)

    cond do
      DynamicExit.open?(room_id, "south") ->
        Helpers.render_to_player(conn, "吊桥已经放下来了。\n")

      arg not in @args ->
        Helpers.render_to_player(conn, "你要开什么？\n")

      true ->
        open_bridge(conn, room_id)
    end
  end

  defp open_bridge(conn, room_id) do
    conn
    |> DynamicExit.open(room_id, "south", @neighbor_room, @opened)
    |> put_neighbor_exit()
    |> schedule_close(room_id)
  end

  # `room->set("exits/north", __FILE__)` + `message("vision", ..., room)`
  defp put_neighbor_exit(conn) do
    Room.set_exit(@neighbor_room, "north", @self_room)
    Room.tell_room(%Room{id: @neighbor_room}, @neighbor_opened)
    conn
  end

  # `close_bridge`：两边各一句不同文案，且没有「出口还在吗」守卫。
  defp schedule_close(conn, room_id) do
    DynamicExit.close_after(@delay_ms, room_id, @timer_key, [
      {room_id, "south", "几位凌霄弟子上前把吊桥关了起来。\n"},
      {@neighbor_room, "north", "只听“嘎嘎嘎嘎”几声，吊桥又被关了起来。\n"}
    ])

    conn
  end
end
