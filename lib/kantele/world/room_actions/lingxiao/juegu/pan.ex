defmodule Kantele.World.RoomActions.Lingxiao.Juegu.Pan do
  @moduledoc """
  `d/lingxiao/juegu.c` 的 `do_pan`（`add_action("do_pan", "climb")`）。

  LPC 原文：

      int do_pan()
      {
              object me = this_player();
              me->move(__DIR__"shiya");
              return 1;
      }

  绝谷没有别的出口，`climb` 是唯一出路（房间里也没有 `climb` 方向出口，
  所以全局 `climb` 命令在这里本来就只会报「没有这个方向」）。移植后爬上去
  直达 `lingxiao:shiya`。无任何文案，纯位移。
  """
  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.Helpers

  @target_room_id "lingxiao:shiya"

  @impl true
  def run(conn, _params) do
    Helpers.move_to(conn, @target_room_id)
  end
end
