defmodule Kantele.World.RoomActions.Quanzhen.FuWoshi.Pull do
  @moduledoc """
  全真侯员外卧室（`d/quanzhen/fu-woshi.c`）的 `do_pull`（`add_action("do_pull","pull")`）。

  拉 `drawer` 开 `down`→`quanzhen:fu-midao`（单向），5 秒后床板合上封住洞口。

  LPC 原文：

      if (! arg || arg != "drawer") return notify_fail("你要拉开什么？\\n");
      message_vision("$N把抽屉拉开...现出一个黑黝黝的洞口。\\n", me);
      set("exits/down", __DIR__"fu-midao");
      remove_call_out("close");
      call_out("close", 5, this_object());
      // close(room) → message("vision", "床板又合了起来...", room); room->delete("exits/down");
  """
  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.Helpers
  alias Kantele.World.RoomActions.KnockPull

  @self_room "quanzhen:fu_woshi"
  @target_room "quanzhen:fu-midao"
  @dir "down"
  @delay_s 5

  @what "你要拉开什么？\n"
  @open_vision "\n$N把抽屉拉开，还没来得及看里面有什么东西，只听得床板吱吱连声，自动向两边分开，现出一个黑黝黝的洞口。\n"
  @close_msg "床板又合了起来，把洞口封住了。\n"

  @impl true
  def run(conn, %{trailing: arg}) do
    arg = String.trim(arg)

    cond do
      arg != "drawer" ->
        Helpers.render_to_player(conn, @what)

      true ->
        KnockPull.reveal_one(conn, @self_room, @dir, @target_room, @open_vision, {@delay_s, @close_msg})
    end
  end
end
