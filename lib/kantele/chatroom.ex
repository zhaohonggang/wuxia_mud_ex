defmodule Kantele.Chatroom do
  @moduledoc """
  聊天室系统（对应 LPC inherit/room/chatroom.c）

  提供私人聊天室功能：
  - 创建聊天室（基于某个房间）
  - 房主管理（ban/invite/踢人）
  - 话题设置
  - 隐私模式（secret）

  ## 数据结构

  聊天室状态：
  ```
  %{
    owner_id: string,
    couple_id: string | nil,
    short: string,
    long: string,
    topic: string | nil,
    secret: boolean,
    ban_all: boolean,
    ban: [player_id, ...],
    can: [player_id, ...],
    members: [player_id, ...]
  }
  ```
  """

  @default_capacity 50

  @doc """
  创建聊天室
  """
  def new(owner_id, opts \\ []) do
    %{
      owner_id: owner_id,
      couple_id: Keyword.get(opts, :couple_id),
      short: Keyword.get(opts, :short, "聊天室"),
      long: Keyword.get(opts, :long, "这里是一个聊天室。"),
      topic: nil,
      secret: false,
      ban_all: false,
      ban: [],
      can: [],
      members: [],
      start_room: Keyword.get(opts, :start_room)
    }
  end

  @doc """
  检查是否为房主
  """
  def owner?(room, player_id) do
    room.owner_id == player_id or room.couple_id == player_id
  end

  @doc """
  检查是否被禁止进入
  """
  def banned?(room, player_id) do
    cond do
      room.ban_all and player_id not in room.can -> true
      player_id in room.ban -> true
      true -> false
    end
  end

  @doc """
  允许进入检查
  """
  def can_enter?(room, player_id) do
    if owner?(room, player_id) do
      {:ok, :owner}
    else
      cond do
        room.ban_all and player_id not in room.can -> {:error, :banned_all}
        player_id in room.ban -> {:error, :banned}
        true -> {:ok, :allowed}
      end
    end
  end

  @doc """
  设置话题
  """
  def set_topic(room, topic, player_id) do
    if owner?(room, player_id) do
      {:ok, %{room | topic: topic}}
    else
      {:error, :not_owner}
    end
  end

  @doc """
  设置隐私模式
  """
  def set_secret(room, secret, player_id) do
    if owner?(room, player_id) do
      {:ok, %{room | secret: secret}}
    else
      {:error, :not_owner}
    end
  end

  @doc """
  禁止某人进入（ban）
  """
  def ban_player(room, target_id, player_id) do
    if owner?(room, player_id) do
      if target_id == player_id do
        {:error, :cannot_ban_self}
      else
        {:ok, %{room | ban: Enum.uniq(room.ban ++ [target_id])}}
      end
    else
      {:error, :not_owner}
    end
  end

  @doc """
  取消禁止某人（unban）
  """
  def unban_player(room, target_id, player_id) do
    if owner?(room, player_id) do
      {:ok, %{room | ban: List.delete(room.ban, target_id)}}
    else
      {:error, :not_owner}
    end
  end

  @doc """
  设置只允许邀请的人进入（ban_all 模式）
  """
  def set_ban_all(room, enabled, player_id) do
    if owner?(room, player_id) do
      {:ok, %{room | ban_all: enabled}}
    else
      {:error, :not_owner}
    end
  end

  @doc """
  添加到白名单（can）
  """
  def add_can(room, target_id, player_id) do
    if owner?(room, player_id) do
      {:ok, %{room | can: Enum.uniq(room.can ++ [target_id])}}
    else
      {:error, :not_owner}
    end
  end

  @doc """
  从白名单移除
  """
  def remove_can(room, target_id, player_id) do
    if owner?(room, player_id) do
      {:ok, %{room | can: List.delete(room.can, target_id)}}
    else
      {:error, :not_owner}
    end
  end

  @doc """
  加入聊天室
  """
  def join(room, player_id) do
    if player_id in room.members do
      {:ok, room}
    else
      {:ok, %{room | members: room.members ++ [player_id]}}
    end
  end

  @doc """
  离开聊天室
  """
  def leave(room, player_id) do
    {:ok, %{room | members: List.delete(room.members, player_id)}}
  end

  @doc """
  获取成员列表
  """
  def members(room), do: room.members

  @doc """
  获取成员数量
  """
  def member_count(room), do: length(room.members)

  @doc """
  检查是否为空聊天室
  """
  def empty?(room), do: room.members == []

  @doc """
  设置短描述
  """
  def set_short(room, short, player_id) do
    if owner?(room, player_id) do
      {:ok, %{room | short: short}}
    else
      {:error, :not_owner}
    end
  end

  @doc """
  设置长描述
  """
  def set_long(room, long, player_id) do
    if owner?(room, player_id) do
      {:ok, %{room | long: long}}
    else
      {:error, :not_owner}
    end
  end
end
