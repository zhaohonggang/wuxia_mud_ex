defmodule Kantele.World.RoomActions.Huashan.Xiuxishi.Close do
  @moduledoc """
  `d/huashan/xiuxishi.c` 的 `do_close`（与 `Open` 成对，双向门手动关闭）。

  LPC 原文：

      int do_close(string arg)
      {
          object room;

          if (!arg || (arg != "men" && arg != "door"))
              return notify_fail("你要关什么？\\n");

          if (!query("exits/west"))
              return notify_fail("门已经是关着的了。\\n");

          message_vision("$N一伸手，把门关上了。\\n", this_player());

          if(!( room = find_object(__DIR__"xiaolu2")) )
              room = load_object(__DIR__"xiaolu2");

          if(objectp(room))
          {
                      message("vision", "门被人从里面关上了。\\n", room);
              delete("exits/west");
              room->delete("exits/east");
          }

          return 1;
      }

  ## 移植要点

  - 参数只认 `men` / `door`（不认 `west`，与 `do_open` 不对称，LPC 原样）。
  - 邻居房文案「门被人从里面关上了。」—— 这里**没有** `guanwai:xiuxishi` 那个
    双「了」笔误，两处原文不同，逐字保留。
  - 与 `guanwai` 版一样，`do_close` 不取消 `do_open` 排的定时器；但本房的
    `close_men` 有 `query("exits/west")` 守卫（`Open` 里已设为
    `only_if_open: true`），所以残留定时器不会多播一句。
  """
  use Kantele.World.RoomAction

  alias Kantele.World.Room
  alias Kantele.World.RoomActions.DynamicExit
  alias Kantele.World.RoomActions.Helpers

  @neighbor_room "huashan:xiaolu2"
  @args ["men", "door"]

  @closed "$N一伸手，把门关上了。\n"
  @neighbor_notice "门被人从里面关上了。\n"

  @impl true
  def run(conn, %{trailing: arg, room_id: room_id}) do
    arg = String.trim(arg)

    cond do
      arg not in @args ->
        Helpers.render_to_player(conn, "你要关什么？\n")

      not DynamicExit.open?(room_id, "west") ->
        Helpers.render_to_player(conn, "门已经是关着的了。\n")

      true ->
        conn
        |> DynamicExit.close(room_id, "west", @closed)
        |> close_neighbor()
    end
  end

  defp close_neighbor(conn) do
    Room.delete_exit(@neighbor_room, "east")
    Room.tell_room(%Room{id: @neighbor_room}, @neighbor_notice)
    conn
  end
end
