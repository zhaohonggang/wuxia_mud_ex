defmodule Kantele.Character.YitianEvent do
  @moduledoc """
  倚天万安寺四关（`Kantele.World.NpcActions.Yitian`）的进程桥接。

  与 `Kantele.Character.BiEvent` 同构：

  - NPC 进程收到 `yitian/begin`：记 anti、出招、安排脚本结算。
  - 玩家进程收到 `yitian/result`：落 `win_*`、清 `bi`、广播死亡文案。
  """

  use Kalevala.Character.Event

  alias Kantele.World.NpcActions.Yitian

  # NPC 进程收到 `yitian/begin`（NonPlayerEvents 路由）。
  def begin_event(conn, event), do: Yitian.on_begin(conn, event)

  # 玩家进程收到 `yitian/result`（Events 路由）。
  def result(conn, event), do: Yitian.client_result(conn, event)
end
