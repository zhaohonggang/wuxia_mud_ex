defmodule Kantele.World.RoomActions.Wudang.Nanyangong.Move do
  @moduledoc """
  武当南阳宫（`d/wudang/nanyangong.c`）的 `do_move`（`add_action("do_move","move")`）。

  推老君像：`move xiang`，无属性门控。开 `down`→`wudang:nanyan0` 并打通暗道
  反向 `up`→本房（双向），**3 秒**后自动关：两侧都播报，但 LPC 只删本房
  `down`（邻房 `up` 不删，照搬）。

  LPC 原文：

      if (! arg || arg != "xiang") return notify_fail("你要移动什么？\\n");
      message_sort("$N走到三清坐像背后，用力使劲推移老君像，慢慢的推着，坐像终于推了。"
                   "像下露出一个大洞，几排石阶往下伸去，从这里分明通向一个暗道。\\n", ob);
      set("exits/down", __DIR__"nanyan0");
      if (room = find_object(__DIR__"nanyan0")) {
          room->set("exits/up", __FILE__);
          message("vision", "天花板忽然发出轧轧的声音，露出一个向上的楼梯。\\n", room);
      }
      remove_call_out("close_andao"); call_out("close_andao", 3);

  `close_andao` 有 `if (! query("exits/down")) return;` 守卫 → `only_if_open: true`；
  回调里两侧 `message("vision", ...)` 但只 `delete("exits/down")`。
  """
  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.MoveStone

  @self_room "wudang:nanyangong"
  @target_room "wudang:nanyan0"
  @dir "down"
  @neighbor_dir "up"
  @close_seconds 3

  @what "你要移动什么？\n"
  @opened "\n$N走到三清坐像背后，用力使劲推移老君像，慢慢的推着，坐像终于推了。像下露出一个大洞，几排石阶往下伸去，从这里分明通向一个暗道。\n\n"
  @neighbor_opened "\n天花板忽然发出轧轧的声音，露出一个向上的楼梯。\n"
  @close_self "\n只听乒地一声响，老君像自动移回原处。\n"
  @close_neighbor "\n只听乒地一声响，向上的洞口自动严严实实地关了起来。\n"

  @impl true
  def run(conn, %{trailing: arg}) do
    if String.trim(arg) != "xiang" do
      MoveStone.render(conn, @what)
    else
      MoveStone.reveal_both(conn, @self_room, @dir, @target_room, @target_room, @neighbor_dir, @opened, @neighbor_opened,
        seconds: @close_seconds,
        self_msg: @close_self,
        neighbor_msg: @close_neighbor,
        only_if_open: true
      )
    end
  end
end
