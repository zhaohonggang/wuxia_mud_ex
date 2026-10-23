defmodule Kantele.World.RoomActions.Jinshe.Shanbi.Break do
  @moduledoc """
  `d/jinshe/shanbi.c` 的 `do_break`（LPC 目标词 `dong`）。

  - 参数非 `dong` → `return 0`（无 notify_fail）→ `:not_handled`。
  - 内力 < 100 → 内力清零 + 昏厥（被土层反弹力震黑）。
  - 否则 → 开 enter→jinshe:yongdao1、扣 200、5 秒后自动关（崖上大土块封洞）。
  """
  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.Break

  @impl true
  def run(conn, %{trailing: arg, room_id: room_id}) do
    if String.trim(arg) != "dong" do
      :not_handled
    else
      conn = Break.broadcast(conn, room_id, "$N走到洞口前，运气双掌，猛地击向土层！\n")

      if Break.neili(Break.current(conn)) < 100 do
        conn
        |> Break.broadcast(room_id, "结果只听一声闷哼，$N被土层的反弹力震得眼前一黑....\n")
        |> Break.pass_out()
      else
        conn
        |> Break.broadcast(room_id, "$N只听一声轰响，土层被捅穿了，原来里面有一个大洞！\n")
        |> Break.reveal(room_id, "enter", "jinshe:yongdao1", "",
          {5, "崖上忽然掉下来一块大土块，将洞口封了个严严实实。\n"}
        )
        |> Break.deduct_neili(200)
      end
    end
  end
end
