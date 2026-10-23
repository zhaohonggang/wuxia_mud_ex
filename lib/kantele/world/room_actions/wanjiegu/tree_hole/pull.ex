defmodule Kantele.World.RoomActions.Wanjiegu.TreeHole.Pull do
  @moduledoc """
  万劫谷树洞（`d/wanjiegu/tree_hole.c`）的 `do_pull`（`add_action("do_pull","pull")`）。

  拉 `大铁环`/`ring` 开 `enter`→`wanjiegu:tunnel1`（单向），10 秒后木板盖住洞口。

  LPC 原文：

      if( !arg ) return 0;
      if( arg != "大铁环" && arg != "ring" ) return 0;
      message_vision("$N用劲拉起大铁环，拎起一块木板，下面露出一洞。\\n", me);
      set("exits/enter", __DIR__ "tunnel1");
      call_out("close_passage", 10);
      // close_passage() → if(!query("exits/enter")) return; delete("exits/enter");
      //   message("vision","木板晃了晃，将下面的洞口盖住了。\\n", this_object());

  LPC 对无参/错词 `return 0`（静默），这里改为渲染「你要拉什么？」提示。`enter`
  为非标准方向键；开门由本 handler 负责，穿行（移动命令）不在本批范围（与其它
  动态出口批次一致）。
  """
  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.Helpers
  alias Kantele.World.RoomActions.KnockPull

  @self_room "wanjiegu:tree_hole"
  @target_room "wanjiegu:tunnel1"
  @dir "enter"
  @delay_s 10

  @what "你要拉什么？\n"
  @open_vision "$N用劲拉起大铁环，拎起一块木板，下面露出一洞。\n"
  @close_msg "木板晃了晃，将下面的洞口盖住了。\n"

  @impl true
  def run(conn, %{trailing: arg}) do
    arg = String.trim(arg)

    cond do
      arg not in ["大铁环", "ring"] ->
        Helpers.render_to_player(conn, @what)

      true ->
        KnockPull.reveal_one(conn, @self_room, @dir, @target_room, @open_vision, {@delay_s, @close_msg})
    end
  end
end
