defmodule Kantele.Character.Teleport do
  @moduledoc """
  房间间瞬移（死亡重生/尸体回收用）

  复用 `MoveEvent.commit` 的两段 Movement 事件机制：旧房间移除角色并转发
  `:to` 事件到目标房间，目标房间加入角色，随后重订阅房间频道。
  """

  import Kalevala.Character.Conn

  alias Kantele.Character.MoveEvent
  alias Kantele.Character.MoveView

  @doc "把角色从当前房间瞬移到 `to_room_id`（保留此前已排队的状态更新）"
  def teleport(conn, to_room_id) do
    latest = conn.private.update_character || conn.character
    from = latest.room_id

    conn
    |> put_character(%{latest | room_id: to_room_id})
    |> move(:from, from, MoveView, "leave", %{})
    |> move(:to, to_room_id, MoveView, "enter", %{})
    |> unsubscribe("rooms:#{from}", [], &MoveEvent.unsubscribe_error/2)
    |> subscribe("rooms:#{to_room_id}", [], &MoveEvent.subscribe_error/2)
    |> event("room/look")
  end
end
