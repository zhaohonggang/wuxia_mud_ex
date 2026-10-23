defmodule Kantele.World.RoomActions.Meizhuang.Didao3.Pull do
  @moduledoc """
  `d/meizhuang/didao3.c` 的 `do_open`（`add_action("do_open", "pull")`）。

  LPC 原文：

      int do_open(string arg)
      {
          object me;

          if (! arg || arg == "")
          {
                  write("你要打开什么？\\n");
                  return 1;
          }

          if (arg == "floor")
          {
                  me = this_player();
                  if (! query("exits/down"))
                  {
                          set("exits/down", __DIR__"didao4");
                          call_out("close_path", 5);
                  } else
                  {
                          write("地上的木板现在已经拉开了。\\n");
                          return 1;
                  }

                  message_vision("$N拉起地上的木板，发现下面是空的。\\n", me);
                  return 1;
              } else
              {
                  write("你没法打开 " + arg + " 这样东西。\\n");
                  return 1;
              }
      }

      void close_path()
      {
          if (! query("exits/down")) return;
          message("vision", "木板又弹了回来，遮住了下面的密道。\\n",
                  this_object());
          delete("exits/down");
      }

  ## 移植要点

  - **动词是 `pull`，不是 `open`**：LPC `add_action("do_open", "pull")` 把函数
    挂在 `pull` 上。`pull` 不在本移植的全局命令表里（`commands.ex` 无
    `parse("pull", ...)`），所以不遮蔽任何全局命令。
  - 参数为空走 `write` + `return 1`（**不是** `notify_fail`）—— 也就是「本次我
    处理了」，不能让别的 handler 接手 → `render_to_player/2`。
  - `call_out("close_path", 5)` → `DynamicExit.close_after/4`，5 秒后
    `delete_exit("down")` 并向房间播报「木板又弹了回来…」。
  - LPC 这里**没有** `remove_call_out`。本移植的 `close_after/4` 会先取消同
    `timer_key` 的旧定时器，但重复拉木板根本走不到那一步（出口已开时直接
    `write("地上的木板现在已经拉开了。")` 返回），所以两者行为一致。
  - `close_path` 首行的 `if (! query("exits/down")) return;` 是「出口已经没了
    就闭嘴」，对应 `DynamicExit.close_after/4` 的 `only_if_open: true`。
  """
  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.DynamicExit
  alias Kantele.World.RoomActions.Helpers

  @target_room "meizhuang:didao4"
  @timer_key "exit_timer:close_path"
  @delay_ms 5_000

  @closed_message "木板又弹了回来，遮住了下面的密道。\n"

  @impl true
  def run(conn, %{trailing: arg, room_id: room_id}) do
    case String.trim(arg) do
      "" ->
        Helpers.render_to_player(conn, "你要打开什么？\n")

      "floor" ->
        pull_floor(conn, room_id)

      other ->
        Helpers.render_to_player(conn, "你没法打开 #{other} 这样东西。\n")
    end
  end

  defp pull_floor(conn, room_id) do
    if DynamicExit.open?(room_id, "down") do
      Helpers.render_to_player(conn, "地上的木板现在已经拉开了。\n")
    else
      conn
      |> DynamicExit.open(
        room_id,
        "down",
        @target_room,
        "$N拉起地上的木板，发现下面是空的。\n"
      )
      |> schedule_close(room_id)
    end
  end

  defp schedule_close(conn, room_id) do
    DynamicExit.close_after(
      @delay_ms,
      room_id,
      @timer_key,
      [{room_id, "down", @closed_message}],
      only_if_open: true
    )

    conn
  end
end
