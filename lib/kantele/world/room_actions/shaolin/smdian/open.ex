defmodule Kantele.World.RoomActions.Shaolin.Smdian.Open do
  @moduledoc """
  `d/shaolin/smdian.c` 的 `do_open`（`add_action("do_open", "open")`）。

  LPC 原文：

      int do_open(string arg)
      {
          object room;

          if (query("exits/south"))
              return notify_fail("大门已经是开着了。\\n");

          if (!arg || (arg != "gate" && arg != "south"))
              return notify_fail("你要开什么？\\n");

          if(!( room = find_object(__DIR__"guangchang1")) )
              room = load_object(__DIR__"guangchang1");
          if(objectp(room))
          {
              set("exits/south", __DIR__"guangchang1");
              message_vision(HIY "$N" HIY "使劲把大门打了开来。\\n" NOR, this_player());
              room->set("exits/north", __FILE__);
              message("vision", HIY "只听吱地一声，里面有人把大门打开了。\\n" NOR, room);
              remove_call_out("close_gate");
              call_out("close_gate", 10);
          }

          return 1;
      }

  ## 移植要点

  - 双向门：`shaolin:smdian` 的 `south` ↔ `shaolin:guangchang1` 的 `north`，
    10 秒后 `close_gate` 两边一起关。
  - 两处守卫顺序照抄：先判「已经开着」，再判参数（`gate` / `south` 两个别名）。
  - 邻居房那句是 `message("vision", ..., room)`，说给广场上的人听，行动者不在那个
    房间，没有 `VisionView` 可渲染，所以用 `Room.tell_room/2` 发纯文本。
  - `close_gate` **没有** `if (query("exits/south"))` 守卫 → `only_if_open` 保持
    默认 `false`。
  - 本房还有 `look_gate`（`item_desc.gate` 的闭包），属 look 子系统，不在本批。
  - `open` 是全局命令；本房 UCL 没有 `doors` 配置，遮蔽不损失既有功能。
  """

  use Kantele.World.RoomAction

  alias Kantele.World.Room
  alias Kantele.World.RoomActions.DynamicExit
  alias Kantele.World.RoomActions.Helpers

  @neighbor_room "shaolin:guangchang1"
  @self_room "shaolin:smdian"
  @timer_key "exit_timer:close_gate"
  @delay_ms 10_000

  @args ["gate", "south"]
  @opened "$N使劲把大门打了开来。\n"
  @neighbor_opened "只听吱地一声，里面有人把大门打开了。\n"

  @impl true
  def run(conn, %{trailing: arg, room_id: room_id}) do
    arg = String.trim(arg)

    cond do
      DynamicExit.open?(room_id, "south") ->
        Helpers.render_to_player(conn, "大门已经是开着了。\n")

      arg not in @args ->
        Helpers.render_to_player(conn, "你要开什么？\n")

      true ->
        open_gate(conn, room_id)
    end
  end

  defp open_gate(conn, room_id) do
    conn
    |> DynamicExit.open(room_id, "south", @neighbor_room, @opened)
    |> put_neighbor_exit()
    |> schedule_close(room_id)
  end

  defp put_neighbor_exit(conn) do
    Room.set_exit(@neighbor_room, "north", @self_room)
    Room.tell_room(%Room{id: @neighbor_room}, @neighbor_opened)
    conn
  end

  defp schedule_close(conn, room_id) do
    DynamicExit.close_after(@delay_ms, room_id, @timer_key, [
      {room_id, "south", "僧兵上前把大门关了起来。\n"},
      {@neighbor_room, "north", "只听乒地一声，里面有人把大门关上了。\n"}
    ])

    conn
  end
end
