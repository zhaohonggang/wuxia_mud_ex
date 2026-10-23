defmodule Kantele.World.RoomActions.Xueshan.Chanshi.Turn do
  @moduledoc """
  雪山禅室（`d/xueshan/chanshi.c`）的 `do_turn`（`add_action("do_turn","turn")`）。

  转轮盘开地洞：`turn lunpan`，无前置条件。开 `down`→`xueshan:midao`，
  8 秒后地面缩回自动关。文案与鳌拜书房同源（同一个「喀喀喀」机关家族）。

  LPC 原文：

      if (! arg || arg != "lunpan") return notify_fail("你要转动什么？\\n");
      message_vision("$N使劲转动轮盘，地面忽然「喀喀喀」现出一个洞口。\\n", me);
      set("exits/down", __DIR__"midao");
      remove_call_out("close"); call_out("close", 8);
  """
  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.Trigger

  @self_room "xueshan:chanshi"
  @target_room "xueshan:midao"
  @dir "down"
  @close_seconds 8

  @what "你要转动什么？\n"
  @opened "$N使劲转动轮盘，地面忽然「喀喀喀」现出一个洞口。\n"
  @close_msg "地面忽然「喀喀喀」缩回原地，把密道的入口挡住了。\n"

  @impl true
  def run(conn, %{trailing: arg}) do
    if String.trim(arg) != "lunpan" do
      Trigger.render(conn, @what)
    else
      Trigger.reveal(conn, @self_room, @dir, @target_room, @opened, @close_msg, @close_seconds)
    end
  end
end
