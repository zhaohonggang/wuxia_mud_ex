defmodule Kantele.World.RoomActions.Lingxiao.Gate.Close do
  @moduledoc """
  `d/lingxiao/gate.c` 的 `do_close`（`add_action("do_close", "close")`）。

  LPC 原文：

      int do_close(string arg)
      {
              if (! query("exits/south"))
                      return notify_fail("吊桥已经是关着的了。\\n");

              if (!arg || (arg != "bridge" && arg != "south"))
                      return notify_fail("你要关什么？\\n");

              message_vision(HIY "$N" HIY "朝凌霄弟子招了一下手，几位弟子点了点"
                             "头，上前将吊桥吊了上去。\\n" NOR, this_player());

              remove_call_out("close_bridge");
              call_out("close_bridge", 2);

              return 1;
      }

  ## 移植要点

  - 关桥是**延迟 2 秒**由 `close_bridge` 完成的，不是立刻：`do_close` 只播
    「招呼弟子」并重置定时器。真正的 `delete("exits/...")` 与「吊桥又被关了起来」
    两句都在 `close_bridge` 里（与 `open` 用的是同一个回调、同一个 `call_out` 槽位，
    所以 `timer_key` 必须与 `Open` 一致：`exit_timer:close_bridge`）。
  - 因此 `open` 后立刻 `close`，`open` 的 10 秒定时器会被这里的 2 秒定时器**顶掉**
    —— 这正是 LPC `remove_call_out` 的语义。
  - 两处守卫顺序与文案照抄；参数接受 `bridge` / `south`。
  - `close` 是全局命令（`CloseCommand` 操作 `room.doors`）；本房 UCL 没有 `doors`
    配置，遮蔽不损失既有功能。
  """

  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.DynamicExit
  alias Kantele.World.RoomActions.Helpers

  @neighbor_room "lingxiao:shanya"
  @timer_key "exit_timer:close_bridge"
  @delay_ms 2_000

  @args ["bridge", "south"]
  @called "$N朝凌霄弟子招了一下手，几位弟子点了点头，上前将吊桥吊了上去。\n"

  @impl true
  def run(conn, %{trailing: arg, room_id: room_id}) do
    arg = String.trim(arg)

    cond do
      not DynamicExit.open?(room_id, "south") ->
        Helpers.render_to_player(conn, "吊桥已经是关着的了。\n")

      arg not in @args ->
        Helpers.render_to_player(conn, "你要关什么？\n")

      true ->
        conn
        |> Helpers.broadcast_vision(room_id, @called)
        |> schedule_close(room_id)
    end
  end

  # 与 `Open` 的 `close_bridge` 完全一致（LPC 是同一个函数）。
  defp schedule_close(conn, room_id) do
    DynamicExit.close_after(@delay_ms, room_id, @timer_key, [
      {room_id, "south", "几位凌霄弟子上前把吊桥关了起来。\n"},
      {@neighbor_room, "north", "只听“嘎嘎嘎嘎”几声，吊桥又被关了起来。\n"}
    ])

    conn
  end
end
