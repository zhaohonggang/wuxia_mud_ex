defmodule Kantele.Item.Transport do
  @moduledoc """
  可驾驶物品/坐骑（对应 `feature/transport.c`）

  - `can_drive_by?/3`: 我能否驾驶这辆车/坐骑（owner 未设 / owner 是我 /
    owner 与我同房间 → 可；否则拒绝）
  - `set_owner/query_owner`: 车主暂态（宿主必要时持久化）

  纯逻辑：owner_id 为车主 id（可为 nil）。
  """

  @doc "是否可驾驶 (is_transport)"
  def is_transport?(_), do: true

  @doc "设置车主 (LPC: set_owner(me))"
  def set_owner(transport, owner_id), do: Map.put(transport, :owner, owner_id)

  @doc "查询车主 (LPC: query_owner)"
  def query_owner(transport), do: Map.get(transport, :owner)

  @doc """
  我能否驾驶 (LPC: can_drive_by(me))

  opts: `%{owner: owner_id, me: me_id, owner_room: owner_room_id, my_room: my_room_id}`
  """
  def can_drive_by?(opts) do
    %{owner: owner, me: me, owner_room: owner_room, my_room: my_room} = opts

    cond do
      owner == nil -> true
      owner == me -> true
      owner_room != my_room -> true
      true -> false
    end
  end
end
