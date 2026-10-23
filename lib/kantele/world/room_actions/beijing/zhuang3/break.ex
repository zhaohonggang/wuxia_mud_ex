defmodule Kantele.World.RoomActions.Beijing.Zhuang3.Break do
  @moduledoc """
  `d/beijing/zhuang3.c` 的 `do_break`（LPC 目标词 `men`）。

  - 参数非 `men` → 仅对玩家提示「不要随便打碎别人的东西！」
  - 内力 ≥ 200 → 开 north→beijing:zhuang5、扣 200、5 秒后自动关（LPC 没写 close，
    继承的默认 close 只删 north，这里静默关）
  - 内力不足 → 内力清零 + 播报「内力不够强」（LPC 不昏厥）
  - 无 `query("break")` 守卫（LPC 也没写），可反复砸。
  """
  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.Break
  alias Kantele.World.RoomActions.Helpers

  @impl true
  def run(conn, %{trailing: arg, room_id: room_id}) do
    if String.trim(arg) != "men" do
      Helpers.render_to_player(conn, "不要随便打碎别人的东西！\n")
    else
      conn = Break.broadcast(conn, room_id, "$N走到门前，深吸一口气，双掌同时拍出。\n")

      if Break.neili(Break.current(conn)) >= 200 do
        conn
        |> Break.reveal(room_id, "north", "beijing:zhuang5",
          "$N只听一声轰响，$N把门震开了！\n", {5, nil})
        |> Break.deduct_neili(200)
      else
        conn = Break.broadcast(conn, room_id,
          "$N大吼一声“开！”，结果什么也没发生。看来$N的内力不够强。\n")
        Break.set_neili(conn, 0)
      end
    end
  end
end
