defmodule Kantele.World.RoomActions.Emei.Shierpan3.Clap do
  @moduledoc """
  P5-1b-3 样板 #2：移植自 `d/emei/shierpan3.c` 的 `do_clap`（`message_vision` 广播）。

  LPC 源（已回源核对）：

      int do_clap()
      {
            message_vision(HIC "\\n池内忽然有蛙大鸣一声，接着群蛙次第相"
                           "合，最后又是一蛙大\\n鸣，群蛙便嘎然而止，其"
                           "数正好为八。\\n", this_player());
            return 1;
      }

  ## 移植要点
  - LPC `message_vision(msg, this_player())` = 向**房间内所有人（含自己）**广播 msg。
    Elixir 侧用 `RoomActions.Helpers.broadcast_vision/3` 走 `rooms:\#{room_id}` 频道、
    `type: "vision"`，由 `Kantele.Character.VisionEvent` 渲染（P3-a 已建）。
  - 动词 `"clap"` 不在全局命令表（`lib/kantele/character/commands.ex`）里注册，
    故本 handler 仅在 `emei:shierpan3` 房间内拦截，不影响任何全局命令（P7 安全）。
  - LPC 颜色宏 `HIC`/`NOR` 在 Elixir 侧无定义，已剥离，仅保留文案（颜色为纯装饰）。
  """
  use Kantele.World.RoomAction

  @text "\n池内忽然有蛙大鸣一声，接着群蛙次第相合，最后又是一蛙大鸣，群蛙便嘎然而止，其数正好为八。\n"

  @impl true
  def run(conn, %{room_id: room_id}) do
    Kantele.World.RoomActions.Helpers.broadcast_vision(conn, room_id, @text)
  end
end
