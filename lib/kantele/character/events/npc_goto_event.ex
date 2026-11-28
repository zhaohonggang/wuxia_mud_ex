defmodule Kantele.Character.NpcGotoEvent do
  @moduledoc """
  NPC 侧瞬移事件（A-5-c C4）：`npc/goto`，data `%{room_id: "zone:key"}`。

  对应 LPC `this_object()->move("<room>")`（康熙 `ask_reward` 门 1 的
  `move("/d/beijing/hg")`，kangxi.c:94）。NPC 进程收到事件后用
  `Kantele.Character.Teleport.teleport/2` 两段 Movement 自移（与玩家
  瞬移同一原语；玩家进程无法代移 NPC，故经事件发回 NPC 进程执行）。

  注册在 `Kantele.Character.NonPlayerEvents`（NPC 侧路由）。
  """

  use Kalevala.Character.Event

  alias Kantele.Character.Teleport

  def call(conn, %{data: %{room_id: room_id}}) when is_binary(room_id) do
    if conn.character.room_id != room_id do
      Teleport.teleport(conn, room_id)
    else
      conn
    end
  end

  def call(conn, _data), do: conn
end
