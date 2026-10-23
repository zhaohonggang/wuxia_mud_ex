defmodule Kantele.World.RoomActions.Room.Panlong.Zoudao.Push do
  @moduledoc """
  `d/room/panlong/zoudao.c` 的 `do_push`（`add_action("do_push", "push")`）。

  推开走道南面通向前庭的木门，同时打通前庭北面回走道的出口，10 秒后自动关门。
  LPC 原文：

      if (query("gate") == "open")
          return notify_fail("大门开着呢，你还推什么？\n");
      ...
      set("gate", "open");
      set("exits/south", __DIR__"qianting");
      room->set("exits/north", __FILE__);
      remove_call_out("do_close");
      call_out("do_close", 10, 0, 1);
  """

  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.DynamicExit
  alias Kantele.World.RoomActions.Helpers
  alias Kantele.World.RoomActions.Room.Panlong.Gate

  @self_room "room:zoudao"
  @neighbor_room "room:qianting"
  @self_dir "south"
  @neighbor_dir "north"
  @self_vision "{npc}用力推了推大门，就听大门“吱呀呀”的被人推开了。\n"
  @neighbor_vision "大门“吱呀呀”的被人推开了。\n"
  @already_open "大门开着呢，你还推什么？\n"

  @impl true
  def run(conn, %{trailing: _arg, room_id: _room_id}) do
    cond do
      DynamicExit.open?(@self_room, @self_dir) ->
        Helpers.render_to_player(conn, @already_open)

      true ->
        {conn, _opened} =
          Gate.open_gate(
            conn,
            @self_room,
            @neighbor_room,
            @self_dir,
            @neighbor_dir,
            @self_vision,
            @neighbor_vision
          )

        conn
    end
  end
end
