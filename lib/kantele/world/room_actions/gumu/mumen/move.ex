defmodule Kantele.World.RoomActions.Gumu.Mumen.Move do
  @moduledoc """
  古墓墓门（`d/gumu/mumen.c`）的 `do_move`（`add_action("do_move","move")`）。

  推巨石开门：`move shi`，无属性门控。开 `south`→`gumu:qianting`，5 秒后
  巨石回位自动关。

  LPC 原文：

      if (!arg || arg != "shi") return notify_fail("你要移动什么？\\n");
      message_vision("$N站在石前，双掌发力推动巨石，只听得巨石吱吱连声，缓\\n缓向后移去，现出一道门户来。\\n", me);
      set("exits/south", __DIR__"qianting");
      remove_call_out("close"); call_out("close", 5, this_object());

  同房 `valid_leave`（孙婆婆 `permit_pass` 准入）已由转换器抽进 UCL，不在本 handler 内。
  """
  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.MoveStone

  @self_room "gumu:mumen"
  @target_room "gumu:qianting"
  @dir "south"
  @close_seconds 5

  @what "你要移动什么？\n"
  @opened "$N站在石前，双掌发力推动巨石，只听得巨石吱吱连声，缓\n缓向后移去，现出一道门户来。\n"
  @close_msg "\n只见巨石又吱吱地回到原地。\n"

  @impl true
  def run(conn, %{trailing: arg}) do
    if String.trim(arg) != "shi" do
      MoveStone.render(conn, @what)
    else
      MoveStone.reveal(conn, @self_room, @dir, @target_room, @opened,
        seconds: @close_seconds,
        close_msg: @close_msg
      )
    end
  end
end
