defmodule Kantele.World.RoomActions.Shaolin.Smdian.Close do
  @moduledoc """
  `d/shaolin/smdian.c` 的 `do_close`（`add_action("do_close", "close")`）。

  LPC 原文：

      int do_close(string arg)
      {
          if (!query("exits/south"))
              return notify_fail("大门已经是关着的了。\\n");

          if (!arg || (arg != "gate" && arg != "south"))
              return notify_fail("你要关什么？\\n");

          message_vision(CYN "$N" CYN "朝着僧兵点了点头。\\n" NOR, this_player());

          remove_call_out("close_gate");
          call_out("close_gate", 2);

          return 1;
      }

  ## 移植要点

  - 关门是**延迟 2 秒**由 `close_gate` 完成的：`do_close` 只播「朝僧兵点头」并
    重置定时器。真正的 `delete("exits/...")` 与两句关门文案都在 `close_gate` 里
    （与 `open` 共用同一个回调与 `call_out` 槽位，故 `timer_key` 必须一致：
    `exit_timer:close_gate`）。
  - 因此 `open` 后立刻 `close`，`open` 的 10 秒定时器会被这里的 2 秒定时器顶掉
    —— LPC `remove_call_out` 的语义。
  - 两处守卫顺序与文案照抄；参数接受 `gate` / `south`。
  - `close` 是全局命令；本房 UCL 没有 `doors` 配置，遮蔽不损失既有功能。
  """

  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.DynamicExit
  alias Kantele.World.RoomActions.Helpers

  @neighbor_room "shaolin:guangchang1"
  @timer_key "exit_timer:close_gate"
  @delay_ms 2_000

  @args ["gate", "south"]
  @nodded "$N朝着僧兵点了点头。\n"

  @impl true
  def run(conn, %{trailing: arg, room_id: room_id}) do
    arg = String.trim(arg)

    cond do
      not DynamicExit.open?(room_id, "south") ->
        Helpers.render_to_player(conn, "大门已经是关着的了。\n")

      arg not in @args ->
        Helpers.render_to_player(conn, "你要关什么？\n")

      true ->
        conn
        |> Helpers.broadcast_vision(room_id, @nodded)
        |> schedule_close(room_id)
    end
  end

  # 与 `Open` 的 `close_gate` 完全一致（LPC 是同一个函数）。
  defp schedule_close(conn, room_id) do
    DynamicExit.close_after(@delay_ms, room_id, @timer_key, [
      {room_id, "south", "僧兵上前把大门关了起来。\n"},
      {@neighbor_room, "north", "只听乒地一声，里面有人把大门关上了。\n"}
    ])

    conn
  end
end
