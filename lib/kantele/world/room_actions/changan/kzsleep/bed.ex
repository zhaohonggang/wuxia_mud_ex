defmodule Kantele.World.RoomActions.Changan.Kzsleep.Bed do
  @moduledoc """
  `d/changan/kzsleep.c` 的 `do_bed`（`add_action("do_bed", "bed")`）。

  LPC 原文：

      int do_bed()
      {       object me;
              me=this_player();
              message_vision(HIY "$N掀开纱帐，准备上床了。\\n\\n" NOR, me);
              me->move(__DIR__"bed");
              message_vision(HIY "\\n沙帐轻轻一动，$N钻了进来。\\n" NOR, me);
              return 1;
      }

  两句 `message_vision` 分处 `move()` 两侧，广播目标房间不同：

  - 第一句在**旧房间**（客房）里说「准备上床」；
  - 第二句在**新房间**（床铺 `changan:bed`）里说「钻了进来」。

  所以第二次广播必须显式传目标房间 id，不能用 `params.room_id`（那是旧房间）。
  `bed` 不是全局命令动词，本 handler 纯新增、不覆盖任何既有玩法。
  """
  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.Helpers

  @target_room_id "changan:bed"

  @before "$N掀开纱帐，准备上床了。\n\n"
  @on_bed "\n沙帐轻轻一动，$N钻了进来。\n"

  @impl true
  def run(conn, %{room_id: room_id}) do
    conn
    |> Helpers.broadcast_vision(room_id, @before)
    |> Helpers.move_to(@target_room_id)
    |> Helpers.broadcast_vision(@target_room_id, @on_bed)
  end
end
