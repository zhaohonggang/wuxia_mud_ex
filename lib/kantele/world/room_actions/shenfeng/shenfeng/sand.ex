defmodule Kantele.World.RoomActions.Shenfeng.Shenfeng.Sand do
  @moduledoc """
  `d/shenfeng/shenfeng.c` 的 `do_move`（`add_action("do_move", "move")`）。

  `move sand` 每执行一次清除一层沙，房间 `mark/sand` 自增；累计 6 层后
  `push gate` 才有机会推开石门。LPC 原文：

      if (! arg || arg != "sand") return notify_fail("你要干什么？\\n");
      if (this_object()->query("mark/sand") > 5)
          return notify_fail("石门上现在已经没有沙子了。\\n");
      if (me->is_busy()) return notify_fail("你正忙着呢。\\n");
      if (this_object()->query("mark/sand") < 5)
          message_vision("$N仔细地清除着覆盖在石门周围的沙子。\\n", me);
      else
          message_vision("$N终于将覆盖在石门周围的沙子清除得干干净净。\\n", me);
      add("mark/sand", 1);
      me->start_busy(2);

  计数落在房间进程 `data.state["mark/sand"]`（`MoveStone.room_temp/3`）。
  """

  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.MoveStone

  @mark_key "mark/sand"

  @impl true
  def run(conn, %{trailing: arg, room_id: room_id}) do
    sand = MoveStone.room_temp(room_id, @mark_key, 0)

    cond do
      String.trim(arg) != "sand" ->
        MoveStone.render(conn, "你要干什么？\n")

      sand > 5 ->
        MoveStone.render(conn, "石门上现在已经没有沙子了。\n")

      MoveStone.busy?(MoveStone.current(conn)) ->
        MoveStone.render(conn, "你正忙着呢。\n")

      true ->
        clear(conn, room_id, sand)
    end
  end

  defp clear(conn, room_id, sand) do
    text =
      if sand < 5 do
        "$N仔细地清除着覆盖在石门周围的沙子。\n"
      else
        "$N终于将覆盖在石门周围的沙子清除得干干净净。\n"
      end

    MoveStone.put_room_temp(room_id, @mark_key, sand + 1)

    conn
    |> MoveStone.broadcast(room_id, text)
    |> MoveStone.start_busy(2)
  end
end
