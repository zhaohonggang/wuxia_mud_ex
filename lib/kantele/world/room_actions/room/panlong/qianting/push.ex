defmodule Kantele.World.RoomActions.Room.Panlong.Qianting.Push do
  @moduledoc """
  `d/room/panlong/qianting.c` 的 `do_push`（`add_action("do_push", "push")`）。

  推开前庭北面通向走道的木门，同时打通走道南面回前庭的出口，10 秒后自动关门。
  LPC 原文：

      if (query("gate") == "open")
          return notify_fail("大门开着呢，你还推什么？\n");
      ...
      set("gate", "open");
      set("exits/north", __DIR__"zoudao");
      room->set("exits/south", __FILE__);
      remove_call_out("do_close");
      call_out("do_close", 10, 0, 1);
  """

  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.DynamicExit
  alias Kantele.World.RoomActions.Helpers
  alias Kantele.World.RoomActions.Room.Panlong.Gate

  @self_room "room:qianting"
  @neighbor_room "room:zoudao"
  @self_dir "north"
  @neighbor_dir "south"
  @self_vision "{npc}用力一推大门，就听见大门“吱呀呀”的开了。\n"
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
