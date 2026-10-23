defmodule Kantele.World.RoomActions.Lingxiao.Didi.Push do
  @moduledoc """
  `d/lingxiao/didi.c` 的 `do_push`（LPC 无参数，推石门）。

  - `max_neili` < 500 → 播报「累了个半死，石门却纹丝不动」，不开门（恒 handle）
  - 否则开 enter→lingxiao:dilao、播报、5 秒后自关
  - LPC 无参数校验，所有 push 动词都被本房拦截（恒返回 conn，不放行全局命令）。
  """
  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.Push

  @room_id "lingxiao:didi"
  @charge "$N气沉丹田，凝劲于腰，大喝一声，运劲向石门推去。\n"
  @failed "$N累了个半死，石门却纹丝不动。\n"
  @opened "顿时只听“喀喀喀”机关枢纽运做之声不绝，石门竟缓缓开了。\n"
  @closed "石门又缓缓地合上了。\n"

  @impl true
  def run(conn, %{room_id: room_id}) do
    char = Push.current(conn)

    conn = Push.broadcast(conn, room_id, @charge)

    if Push.max_neili(char) < 500 do
      Push.broadcast(conn, room_id, @failed)
    else
      Push.reveal(conn, room_id, "enter", "lingxiao:dilao", @opened,
        [{room_id, "enter", @closed}], 5)
    end
  end
end
