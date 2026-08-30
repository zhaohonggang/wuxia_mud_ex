defmodule Kantele.World.Room.Const do
  @moduledoc """
  房间常量（对应 LPC include/room.h 和 inherit/room/room.c）

  定义房间相关的常量，包括：
  - MAX_ITEM_IN_ROOM - 房间最大物品数
  - Door states - 门的状态
  - Room types - 特殊房间类型
  """

  @doc "房间最大物品数量（LPC MAX_ITEM_IN_ROOM）"
  def max_item_in_room, do: 999

  @doc "门状态：关闭"
  def door_closed, do: 1
  @doc "门状态：锁定"
  def door_locked, do: 2
  @doc "门状态：破损"
  def door_smashed, do: 4

  @doc "聊天房间类型"
  def chat_room, do: "/inherit/room/chatroom"
  @doc "创建聊天室"
  def create_chat_room, do: "/inherit/room/create"
  @doc "生产房间"
  def producing_room, do: "/inherit/room/producing"
  @doc "传送房间"
  def trans_room, do: "/inherit/room/trans"
end
