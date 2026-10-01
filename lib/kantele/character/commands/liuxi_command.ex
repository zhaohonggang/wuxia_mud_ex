defmodule Kantele.Character.LiuxiCommand do
  @moduledoc """
  柳溪方向：`liuxi` / `柳溪`

  对应 LPC `city/guangchang.c` 的出口

      "liuxi" : "/d/minimal_world/guangchang",

  以及 LPC `cmds/std/liuxi.c` 占用的这个词。

  这里原本是个只打印「柳溪系统暂未开放。」的桩。因为它没有发出移动请求，
  扬州广场上那个 `liuxi` 方向玩家看得到、却走不过去 —— 出口在
  `data/world/city.ucl` 里是 `liuxi = liuxi.rooms.guangchang.id`，指向已安装的
  柳溪镇 `data/world/liuxi.ucl` 的广场。

  现在改为真正的移动：走 `liuxi` 就是走当前房间的 `liuxi` 出口，落到
  `liuxi:guangchang`；反向由 `liuxi:guangchang` 的 `yangzhou` 出口接回
  `city:guangchang`。

  保留本模块而不并入 `Kantele.Character.MoveCommand`，是为了留住 LPC 的出处，
  以及 `柳溪` 这个中文别名（MoveCommand 那边只有 ASCII 方向名）。
  """

  use Kalevala.Character.Command

  def run(conn, _params) do
    conn
    |> request_movement("liuxi")
    |> assign(:prompt, false)
  end
end