defmodule Kantele.World.RoomActions.Guanwai.Jingxiu.Knock do
  @moduledoc """
  `d/guanwai/jingxiu.c` 的 `do_knock`（`add_action("do_knock", "knock")`）。

  静修室南门外敲门：门已开则提示；否则按邻居 `guanwai:xiuxishi` 的
  `sleeping_person` / `person_inside` 状态播三选一文案，并往休息室里送一句
  「外面传来一阵敲门声……」。语义与文案全部在共享原语
  `Kantele.World.RoomActions.RestKnock`（与 `huashan:xiaolu2` 逐字同源），本模块
  只提供房间参数：出口方向 `south`、邻居 `guanwai:xiuxishi`。
  """
  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.RestKnock

  @impl true
  def run(conn, %{trailing: arg, room_id: room_id}) do
    RestKnock.knock(conn, room_id, "south", "guanwai:xiuxishi", arg)
  end
end
