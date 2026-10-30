defmodule Kantele.Character.TeleportEvent do
  @moduledoc """
  外部进程发起的强制位移（LPC `ob->move(<room>)`）。

  NPC 进程没有玩家的 `conn`，无法直接调用 `Kantele.Character.Teleport.teleport/2`
  （那条路径要改角色自己的 `room_id`、重订阅房间频道）。所以由 NPC 侧发
  `character/teleport` 事件，玩家进程收到后自己完成两段 Movement。

  首个调用点：妓院老鸨把太监踢出门外
  （`d/luoyang/npc/laobao.c`、`d/beijing/npc/laobaopo.c`、`d/city/npc/wei.c`
  的 `greeting()` 里 `me->move("/d/.../xxx")`）。

  - `event("character/teleport", %{room_id: "luoyang:sroad5"})` → 瞬移
  """

  alias Kantele.Character.Teleport

  @doc "topic: character/teleport -> run/1"
  def run(conn, %{data: %{room_id: room_id}}) when is_binary(room_id) do
    Teleport.teleport(conn, room_id)
  end

  def run(conn, _data), do: conn
end
