defmodule Kantele.World.RoomActions.Room.Panlong.Qianting.Close do
  @moduledoc """
  `d/room/panlong/qianting.c` 的 `do_close`（`add_action("do_close", "close")`）。

  关上前庭北面的木门，同时关上走道南面回前庭的出口，取消自动关门定时器。
  LPC 原文：

      if (query("gate") == "close")
          return notify_fail("大门关着呢，你还再关一遍？\n");
      ...
      set("gate", "close");
      delete("exits/north");
      room->delete("exits/south");
  """

  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.DynamicExit
  alias Kantele.World.RoomActions.Helpers
  alias Kantele.World.RoomActions.Room.Panlong.Gate

  @self_room "room:qianting"
  @neighbor_room "room:zoudao"
  @self_dir "north"
  @neighbor_dir "south"
  @self_vision "{npc}走上前去，用力合上大门。\n"
  @neighbor_vision "大门“吱呀呀”的被人关上了。\n"
  @already_closed "大门关着呢，你还再关一遍？\n"

  @impl true
  def run(conn, %{trailing: _arg, room_id: _room_id}) do
    cond do
      not DynamicExit.open?(@self_room, @self_dir) ->
        Helpers.render_to_player(conn, @already_closed)

      true ->
        {conn, _closed} =
          Gate.close_gate(
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
