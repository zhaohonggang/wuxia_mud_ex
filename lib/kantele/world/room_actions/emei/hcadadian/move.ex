defmodule Kantele.World.RoomActions.Emei.Hcadadian.Move do
  @moduledoc """
  峨眉华藏殿（`d/emei/hcadadian.c`）的 `do_move`（`add_action("do_move","move")`）。

  移普贤菩萨像：`move xiang`，无属性门控。已移开则提示；否则开
  `down`→`emei:midao`，8 秒后坐像缩回自动关。

  LPC 原文：

      if (! arg || arg != "xiang") return notify_fail("你要移动什么？\\n");
      if (query("exits/down")) return notify_fail("座像已经被移开了。\\n");
      message_vision("$N刚一推动普贤菩萨像，那座像却自己向一方移开，地面现出一个洞口。\\n", me);
      set("exits/down", __DIR__"midao");
      remove_call_out("close"); call_out("close", 8, this_object());
  """
  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.DynamicExit
  alias Kantele.World.RoomActions.MoveStone

  @self_room "emei:hcadadian"
  @target_room "emei:midao"
  @dir "down"
  @close_seconds 8

  @what "你要移动什么？\n"
  @already_open "座像已经被移开了。\n"
  @opened "\n$N刚一推动普贤菩萨像，那座像却自己向一方移开，地面现出一个洞口。\n\n"
  @close_msg "忽然只听「喀喀喀」几声，普贤菩萨像缩回原地，把密道挡住了。\n"

  @impl true
  def run(conn, %{trailing: arg}) do
    cond do
      String.trim(arg) != "xiang" ->
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
