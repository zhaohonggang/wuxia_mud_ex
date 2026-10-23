defmodule Kantele.World.RoomActions.Meizhuang.Tianjing.Open do
  @moduledoc """
  `d/meizhuang/tianjing.c` 的 `do_open`（`add_action("do_open", "open")`）。

  LPC 原文：

      int do_open(string arg)
      {
              object room;
              if (query("exits/south"))
                      return notify_fail("大门已经是开着了。\\n");
              if (!arg || (arg != "gate" && arg != "south"))
                      return notify_fail("你要开什么？\\n");
              if(!( room = find_object(__DIR__"gate")) )
                      room = load_object(__DIR__"gate");
              if(objectp(room))
              {
                      set("exits/south", __DIR__"gate");
                      message_vision("$N使劲把大门打了开来。\\n", this_player());
                      room->set("exits/north", __FILE__);
                      message("vision", "吱地一声，里面有人把大门打开了。\\n", room);
                      remove_call_out("close_gate");
                      call_out("close_gate", 10);
              }
              return 1;
      }

      void close_gate()
      {
              object room;
              if(!( room = find_object(__DIR__"gate")) )
                      room = load_object(__DIR__"gate");
              if(objectp(room))
              {
                      delete("exits/south");
                      message("vision", "护院上前把大门关了起来。\\n", this_object());
                      room->delete("exits/north");
                      message("vision", "乒地一声，里面有人把大门关上了。\\n", room);
              }
      }

  ## 移植要点

  - **双向门**：本房 `south` ↔ `meizhuang:gate` 的 `north` 同时打开，两处都
    `set_exit`；10 秒后 `close_gate` 把两边一起关掉。
  - 守卫：`query("exits/south")` 已开 → 「大门已经是开着了。」；参数非 `gate`/`south`
    → 「你要开什么？」。
  - 本房广播用 `message_vision`（$N → 你/名字），经 `DynamicExit.open/5` 的 vision
    参数；隔壁 `meizhuang:gate` 的播报把 `me->name()` 拼进文本，用 `Room.tell_room`
    直发纯文本（行动者不在那个房间，没有 `VisionView` 可渲染）。
  - `remove_call_out("close_gate")` + `call_out("close_gate", 10)` →
    `DynamicExit.close_after/4`（同一 `timer_key` 只保留一个定时器）。
  - `close` 没有玩家手动动词（LPC 里只有定时器回调关），故本房无需 `Close` 模块。
  """
  use Kantele.World.RoomAction

  alias Kantele.World.Room
  alias Kantele.World.RoomActions.DynamicExit
  alias Kantele.World.RoomActions.Helpers

  @neighbor_room "meizhuang:gate"
  @self_room "meizhuang:tianjing"
  @timer_key "exit_timer:close_gate"
  @delay_ms 10_000

  @args ["gate", "south"]
  @opened_self "$N使劲把大门打了开来。\n"
  @neighbor_opened "吱地一声，里面有人把大门打开了。\n"
  @self_closed "护院上前把大门关了起来。\n"
  @neighbor_closed "乒地一声，里面有人把大门关上了。\n"

  @impl true
  def run(conn, %{trailing: arg, room_id: room_id}) do
    arg = String.trim(arg)

    cond do
      DynamicExit.open?(room_id, "south") ->
        Helpers.render_to_player(conn, "大门已经是开着了。\n")

      not (arg in @args) ->
        Helpers.render_to_player(conn, "你要开什么？\n")

      true ->
        open_gate(conn, room_id)
    end
  end

  defp open_gate(conn, room_id) do
    conn
    |> DynamicExit.open(room_id, "south", @neighbor_room, @opened_self)
    |> set_neighbor_exit()
    |> tell_neighbor()
    |> schedule_close(room_id)
  end

  # 邻居房的 `north` 出口：`room->set("exits/north", __FILE__)`
  defp set_neighbor_exit(conn) do
    Room.set_exit(@neighbor_room, "north", @self_room)
    conn
  end

  # 隔壁播报拼了 `me->name()`，不是 `$N`：直接 `Room.tell_room` 发纯文本。
  defp tell_neighbor(conn) do
    Room.tell_room(%Room{id: @neighbor_room}, @neighbor_opened)
    conn
  end

  defp schedule_close(conn, room_id) do
    DynamicExit.close_after(@delay_ms, room_id, @timer_key, [
      {room_id, "south", @self_closed},
      {@neighbor_room, "north", @neighbor_closed}
    ])

    conn
  end
end
