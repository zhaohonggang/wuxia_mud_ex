defmodule Kantele.World.RoomActions.Wudu.Huating2.Move do
  @moduledoc """
  五毒教花厅（`d/wudu/huating2.c`）的 `do_move`（`add_action("do_move","move")`）。

  移香炉：`move lu`，无属性门控。已移开则提示；否则开 `down`→`wudu:midao`，
  8 秒后香炉缩回自动关。形状与峨眉华藏殿一致（同一套「像/炉自己移开」文案家族）。

  LPC 原文：

      if (! arg || arg != "lu") return notify_fail("你要移动什么？\\n");
      if (query("exits/down")) return notify_fail("香炉已经被移开了。\\n");
      message_vision("$N刚一推动香炉，香炉却自己向一方移开，地面豁然现出一个洞口。\\n", me);
      set("exits/down", __DIR__"midao");
      remove_call_out("close"); call_out("close", 8, this_object());
  """
  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.DynamicExit
  alias Kantele.World.RoomActions.MoveStone

  @self_room "wudu:huating2"
  @target_room "wudu:midao"
  @dir "down"
  @close_seconds 8

  @what "你要移动什么？\n"
  @already_open "香炉已经被移开了。\n"
  @opened "\n$N刚一推动香炉，香炉却自己向一方移开，地面豁然现出一个洞口。\n\n"
  @close_msg "忽然只听「喀喀喀」几声，香炉缩回原地，把密道挡住了。\n"

  @impl true
  def run(conn, %{trailing: arg}) do
    cond do
      String.trim(arg) != "lu" ->
        MoveStone.render(conn, @what)

      DynamicExit.open?(@self_room, @dir) ->
        MoveStone.render(conn, @already_open)

      true ->
        MoveStone.reveal(conn, @self_room, @dir, @target_room, @opened,
          seconds: @close_seconds,
          close_msg: @close_msg
        )
    end
  end
end
