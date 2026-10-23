defmodule Kantele.World.RoomActions.Wanjiegu.Grassland.Knock do
  @moduledoc """
  万劫谷草地（`d/wanjiegu/grassland.c`）的 `do_knock`（`add_action("do_knock","knock")`）。

  敲 `段`/`duan` 开 `north`→`wanjiegu:xiaoting`（单向），10 秒后门被人关上。

  LPC 原文：

      if (!arg) return 0;
      if (arg != "段" && arg != "duan") return 0;
      message_vision("$N拿起铁锤在第二个字“段”上敲了一下。\\n", me);
      message_vision("只听里面有人应了一声，“来了！”\\n", me);
      message_vision("有人从里面将门打开了。\\n", me);
      set("exits/north", __DIR__ "xiaoting");
      call_out("close_passage", 10);

  无「已开」守卫：反复敲会覆盖并（经 `close_after`）重置 10 秒定时器。LPC 对无参/
  错词 `return 0`（静默），这里改为渲染「你要敲什么？」提示。
  """
  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.Helpers
  alias Kantele.World.RoomActions.KnockPull

  @self_room "wanjiegu:grassland"
  @target_room "wanjiegu:xiaoting"
  @dir "north"
  @delay_s 10

  @what "你要敲什么？\n"
  @open_vision "$N拿起铁锤在第二个字“段”上敲了一下。\n只听里面有人应了一声，“来了！”\n有人从里面将门打开了。\n"
  @close_msg "门被人关上了。\n"

  @impl true
  def run(conn, %{trailing: arg}) do
    arg = String.trim(arg)

    cond do
      arg not in ["段", "duan"] ->
        Helpers.render_to_player(conn, @what)

      true ->
        KnockPull.reveal_one(conn, @self_room, @dir, @target_room, @open_vision, {@delay_s, @close_msg})
    end
  end
end
