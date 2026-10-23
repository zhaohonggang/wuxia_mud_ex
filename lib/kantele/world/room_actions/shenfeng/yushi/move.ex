defmodule Kantele.World.RoomActions.Shenfeng.Yushi.Move do
  @moduledoc """
  神峰玉室（`d/shenfeng/yushi.c`）的 `do_move`（`add_action("do_move","move")`）。

  拉圆桌露洞口：`move table`，须先爬过玉床拿到 `marks/爬1`（同房 `do_climb`
  置位，属移动类 verb、不在本批）；该标记**读完即删**。开 `enter`→
  `shenfeng:yongdao5` 并打通甬道反向 `out`→本房（**双向、无定时关**）。

  LPC 原文：

      if (! me->query_temp("marks/爬1")) { write("什么？\\n"); return 1; }
      if (! arg || arg != "table") { write("你要移动什么？\\n"); return 1; }
      room = load_object(__DIR__"yongdao5");
      this_player()->delete_temp("marks/爬1");
      if (! query("exits/enter")) {
          set("exits/enter", __DIR__"yongdao5");
          message_vision("$N把圆桌边沿缓缓拉动，使桌面所刻骆驼的头和身子连在一起，玉床登时露出一个洞口。\\n", me);
          room->set("exits/out", __FILE__);
          return 1;
      }
      write("你要移动什么？\\n");   // 已开时的兜底文案（LPC 原样，语义略怪）
      return 1;
  """
  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.DynamicExit
  alias Kantele.World.RoomActions.MoveStone

  @self_room "shenfeng:yushi"
  @target_room "shenfeng:yongdao5"
  @dir "enter"
  @neighbor_dir "out"
  @mark_key "marks/爬1"

  @no_mark "什么？\n"
  @what "你要移动什么？\n"
  @opened "\n$N把圆桌边沿缓缓拉动，使桌面所刻骆驼的头和身子连在一起，玉床登时露出一个洞口。\n\n"

  @impl true
  def run(conn, %{trailing: arg}) do
    cond do
      MoveStone.temp(conn, @mark_key) in [nil, 0] ->
        MoveStone.render(conn, @no_mark)

      String.trim(arg) != "table" ->
        MoveStone.render(conn, @what)

      true ->
        pull_table(conn)
    end
  end

  defp pull_table(conn) do
    conn = MoveStone.consume_temp(conn, @mark_key)

    if DynamicExit.open?(@self_room, @dir) do
      MoveStone.render(conn, @what)
    else
      MoveStone.reveal_both(conn, @self_room, @dir, @target_room, @target_room, @neighbor_dir, @opened, "", [])
    end
  end
end
