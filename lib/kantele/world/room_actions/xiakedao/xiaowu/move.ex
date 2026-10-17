defmodule Kantele.World.RoomActions.Xiakedao.Xiaowu.Move do
  @moduledoc """
  `d/xiakedao/xiaowu.c` 的 `do_move`（`add_action("do_move","move")`）。

  LPC 原文：

      int do_move(string arg)
      {
              object me;

              me = this_player();
              if (arg != "bed") return 0;
              message_vision("$N用力把小床移开，发现里面竟然有一条秘密通道！\\n", me);
              me->move(__DIR__"midao1");
              tell_object(me, "接着是一阵轰隆隆的响声，你定神一看，自己已经处身在秘密通道中了。\\n");
              return 1;
      }

  - `arg != "bed"` 时 **`return 0`** —— 本次不处理、交回命令解析。本 handler
    对应返回 `:not_handled`（`move` 不是全局命令，最终会落到「无法理解」）。
  - 命中时：旧房间广播「把小床移开」→ 瞬移到 `xiakedao:midao1` → 只对本人
    补一句「已经处身在秘密通道中」。
  """
  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.Helpers

  @target_room_id "xiakedao:midao1"

  @reveal "$N用力把小床移开，发现里面竟然有一条秘密通道！\n"
  @arrived "接着是一阵轰隆隆的响声，你定神一看，自己已经处身在秘密通道中了。\n"

  @impl true
  def run(conn, %{trailing: arg, room_id: room_id}) do
    case String.trim(arg) do
      "bed" ->
        conn
        |> Helpers.broadcast_vision(room_id, @reveal)
        |> Helpers.move_to(@target_room_id)
        |> Helpers.render_to_player(@arrived)

      _ ->
        :not_handled
    end
  end
end
