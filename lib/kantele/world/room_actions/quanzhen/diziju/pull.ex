defmodule Kantele.World.RoomActions.Quanzhen.Diziju.Pull do
  @moduledoc """
  全真弟子居（`d/quanzhen/diziju.c`）的 `do_pull`（`add_action("do_pull","pull")`）。

  拉 `cabinet` 开 `down`→`quanzhen:mishi`（单向），8 秒后柜子合上挡住入口。

  LPC 原文：

      if (! arg || arg != "cabinet") return notify_fail("你要拉开什么？\\n");
      message_vision("$N使劲把柜子拉开，现出一个洞口...\\n", me);
      set("exits/down", __DIR__"mishi");
      remove_call_out("close");
      call_out("close", 8, this_object());
      // close(room) → message("vision", "柜子又吱吱地回到原地...", room); room->delete("exits/down");
  """
  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.Helpers
  alias Kantele.World.RoomActions.KnockPull

  @self_room "quanzhen:diziju"
  @target_room "quanzhen:mishi"
  @dir "down"
  @delay_s 8

  @what "你要拉开什么？\n"
  @open_vision "\n$N使劲把柜子拉开，现出一个洞口。原来这里是密室的入口。\n\n"
  @close_msg "柜子又吱吱地回到原地，把入口挡住了。\n"

  @impl true
  def run(conn, %{trailing: arg}) do
    arg = String.trim(arg)

    cond do
      arg != "cabinet" ->
        Helpers.render_to_player(conn, @what)

      true ->
        KnockPull.reveal_one(conn, @self_room, @dir, @target_room, @open_vision, {@delay_s, @close_msg})
    end
  end
end
