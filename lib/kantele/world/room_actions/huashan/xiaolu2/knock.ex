defmodule Kantele.World.RoomActions.Huashan.Xiaolu2.Knock do
  @moduledoc """
  `d/huashan/xiaolu2.c` 的 `do_knock`（`add_action("do_knock", "knock")`）。

  华山小路休息室门外敲门：与 `guanwai:jingxiu` 的 `do_knock` **逐字同源**，仅
  出口方向（`east`）与邻居休息室（`huashan:xiuxishi`）不同。语义与文案见共享原语
  `Kantele.World.RoomActions.RestKnock`。
  """
  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.RestKnock

  @impl true
  def run(conn, %{trailing: arg, room_id: room_id}) do
    RestKnock.knock(conn, room_id, "east", "huashan:xiuxishi", arg)
  end
end
