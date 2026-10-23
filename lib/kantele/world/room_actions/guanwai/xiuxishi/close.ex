defmodule Kantele.World.RoomActions.Guanwai.Xiuxishi.Close do
  @moduledoc """
  `d/guanwai/xiuxishi.c` 的 `do_close`（与 `Open` 成对，双向门手动关闭）。

  LPC 原文：

      int do_close(string arg)
      {
              object room;

              if(!( room = find_object(__DIR__"jingxiu")) )
                      room = load_object(__DIR__"jingxiu");

              if (!arg || (arg != "men" && arg != "door"))
                      return notify_fail("你要关什么？\\n");

              if (!query("exits/north"))
                      return notify_fail("门已经是关着的了。\\n");

              message_vision("$N轻手轻脚的把门关上了。\\n", this_player());
              delete("exits/north");

              if(objectp(room))
              {
                      room->delete("exits/south");
                      message("vision", "门被人从里面关上了了。\\n", room);
              }

              return 1;
      }

  ## 移植要点

  - 参数只认 `men` / `door`（**不认 `north`**，与 `do_open` 接受 `south` 不对称，
    这是 LPC 原样）。
  - 邻居房文案「门被人从里面关上了了。」末尾的**双「了」是 LPC 原文的笔误**，
    这里逐字保留（本项目对文案的约定是字节级忠实；只有占位符/转义类 bug 才修）。
  - `do_close` **不** `remove_call_out("close_men")`：手动关门后，`do_open` 时排
    的 10 秒定时器仍会触发，再播一次「门吱吱呀呀地自己合上了」。这是 LPC 原
    行为（此时出口已删，`delete_exit` 无副作用，只有多一句文案），本移植照搬。
  """
  use Kantele.World.RoomAction

  alias Kantele.World.Room
  alias Kantele.World.RoomActions.DynamicExit
  alias Kantele.World.RoomActions.Helpers

  @neighbor_room "guanwai:jingxiu"
  @args ["men", "door"]

  @closed "$N轻手轻脚的把门关上了。\n"
  @neighbor_notice "门被人从里面关上了了。\n"

  @impl true
  def run(conn, %{trailing: arg, room_id: room_id}) do
    arg = String.trim(arg)

    cond do
      arg not in @args ->
        Helpers.render_to_player(conn, "你要关什么？\n")

      not DynamicExit.open?(room_id, "north") ->
        Helpers.render_to_player(conn, "门已经是关着的了。\n")

      true ->
        conn
        |> DynamicExit.close(room_id, "north", @closed)
        |> close_neighbor()
    end
  end

  defp close_neighbor(conn) do
    Room.delete_exit(@neighbor_room, "south")
    Room.tell_room(%Room{id: @neighbor_room}, @neighbor_notice)
    conn
  end
end
