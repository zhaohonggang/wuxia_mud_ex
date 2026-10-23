defmodule Kantele.World.RoomActions.Heimuya.Huoting.Circle do
  @moduledoc """
  黑木崖火盆房（`d/heimuya/huoting.c`）的 `do_circle`（`add_action("do_circle","circle")`）。

  旋碗开/关侧墙洞口：`circle wan`，臂力 ≥ 12 才能旋动。已开 → 关（封洞口）；
  未开 → 开 `down`→`heimuya:didao1` 并打通地道的反向 `out`→本房。没有定时自关
  （LPC 无 `call_out`），靠玩家再 `circle wan` 关上。

  LPC 原文：

      if ((arg != "wan") || ! arg) return notify_fail("你要旋什么？\\n");
      if ((int)me->query("str") < 12) return notify_fail("你臂力连旋不开什么！\\n");
      if (! query("exits/down")) {
          set("exits/down", __DIR__"didao1");
          message_vision("$N将碗旋开，见侧墙打开露，出一个黑幽幽的洞口.\\n", me);
          room->set("exits/out", __DIR__"huoting");
          return notify_fail("一定要抓紧时间，走后将它关上。\\n");
      }
      delete("exits/down");
      message_vision("很快碗又搬回了原位。侧墙上的洞口又被封住了。\\n", me);
      room->delete("exits/out");
      message("vision", "外面传来一阵搬动碗的声音，洞口被封住了。\\n", room);

  LPC 开门后 `return notify_fail(...)`（先开了门、再把「抓紧时间」当失败提示报出来），
  这里顺序照搬：先开两边出口 + 广播，再给玩家补一句提示。
  """
  use Kantele.World.RoomAction

  alias Kantele.World.Room
  alias Kantele.World.RoomActions.DynamicExit
  alias Kantele.World.RoomActions.Trigger

  @self_room "heimuya:huoting"
  @target_room "heimuya:didao1"
  @dir "down"
  @neighbor_dir "out"
  @min_str 12

  @what "你要旋什么？\n"
  @too_weak "你臂力连旋不开什么！\n"
  @open_self "$N将碗旋开，见侧墙打开露，出一个黑幽幽的洞口.\n"
  @hurry "一定要抓紧时间，走后将它关上。\n"
  @close_self "很快碗又搬回了原位。侧墙上的洞口又被封住了。\n"
  @neighbor_closed "外面传来一阵搬动碗的声音，洞口被封住了。\n"

  @impl true
  def run(conn, %{trailing: arg}) do
    arg = String.trim(arg)

    cond do
      arg != "wan" ->
        Trigger.render(conn, @what)

      Trigger.str(Trigger.current(conn)) < @min_str ->
        Trigger.render(conn, @too_weak)

      DynamicExit.open?(@self_room, @dir) ->
        close_bowl(conn)

      true ->
        open_bowl(conn)
    end
  end

  defp open_bowl(conn) do
    conn = DynamicExit.open(conn, @self_room, @dir, @target_room, @open_self)
    Room.set_exit(@target_room, @neighbor_dir, @self_room)
    Trigger.render(conn, @hurry)
  end

  defp close_bowl(conn) do
    conn = DynamicExit.close(conn, @self_room, @dir, @close_self)
    Room.delete_exit(@target_room, @neighbor_dir)
    Room.tell_room(%Room{id: @target_room}, @neighbor_closed)
    conn
  end
end
