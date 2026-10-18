defmodule Kantele.Character.BiEvent do
  @moduledoc false

  use Kalevala.Character.Event

  alias Kantele.World.NpcActions.Bi

  # NPC 进程收到 `bi/begin`：记 anti、落自重 condition、call_out / 三连击。
  def begin_event(conn, event), do: Bi.on_begin(conn, event)

  # 玩家进程收到 `bi/result`：落 win_*、清 bi、清 condition、广播死亡文案。
  def result(conn, event), do: Bi.client_result(conn, event)
end
