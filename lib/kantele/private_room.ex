defmodule Kantele.PrivateRoom do
  @moduledoc """
  私人房间系统（对应 LPC inherit/room/privateroom.c）

  提供私人房屋功能：
  - 房间所有权（owner_id）
  - 门锁管理（lock/unlock/break）
  - 描述保存
  - 自动加载物品

  ## 数据结构

  ```
  %{
    room_owner_id: string,
    short: string,
    long: string,
    key_door: string | nil,
    door_state: :open | :closed | :locked,
    door_room: string | nil,
    autoload: [item, ...]
  }
  ```
  """

  @door_open 0
  @door_closed 1
  @door_locked 2

  @doc "门状态：开放"
  def door_open, do: @door_open
  @doc "门状态：关闭"
  def door_closed, do: @door_closed
  @doc "门状态：锁定"
  def door_locked, do: @door_locked

  @doc """
  创建私人房间
  """
  def new(owner_id, opts \\ []) do
    %{
      room_owner_id: owner_id,
      short: Keyword.get(opts, :short, "私人房间"),
      long: Keyword.get(opts, :long, "这是一间私人房间。"),
      key_door: Keyword.get(opts, :key_door),
      door_state: @door_closed,
      door_room: Keyword.get(opts, :door_room),
      autoload: []
    }
  end

  @doc """
  检查是否为房主
  """
  def room_owner?(room, player_id) do
    room.room_owner_id == player_id
  end

  @doc """
  获取房间所有者ID
  """
  def room_owner_id(room), do: room.room_owner_id

  @doc """
  开锁
  """
  def unlock(room, player_id) do
    if room_owner?(room, player_id) or room.door_state != @door_locked do
      {:ok, %{room | door_state: @door_closed}}
    else
      {:error, :not_owner}
    end
  end

  @doc """
  上锁
  """
  def lock(room, player_id) do
    if room_owner?(room, player_id) do
      {:ok, %{room | door_state: @door_locked}}
    else
      {:error, :not_owner}
    end
  end

  @doc """
  关门
  """
  def close_door(room, player_id) do
    if room_owner?(room, player_id) do
      {:ok, %{room | door_state: @door_closed}}
    else
      {:error, :not_owner}
    end
  end

  @doc """
  开门
  """
  def open_door(room, player_id) do
    if room_owner?(room, player_id) and room.door_state == @door_closed do
      {:ok, %{room | door_state: @door_open}}
    else
      {:error, :not_owner_or_locked}
    end
  end

  @doc """
  检查是否上锁
  """
  def locked?(room), do: room.door_state == @door_locked

  @doc """
  检查门是否开着
  """
  def open?(room), do: room.door_state == @door_open

  @doc """
  设置短描述
  """
  def set_short(room, short, player_id) do
    if room_owner?(room, player_id) do
      {:ok, %{room | short: short}}
    else
      {:error, :not_owner}
    end
  end

  @doc """
  设置长描述
  """
  def set_long(room, long, player_id) do
    if room_owner?(room, player_id) do
      {:ok, %{room | long: long}}
    else
      {:error, :not_owner}
    end
  end

  @doc """
  添加自动加载物品
  """
  def add_autoload(room, item_id) do
    {:ok, %{room | autoload: Enum.uniq(room.autoload ++ [item_id])}}
  end

  @doc """
  移除自动加载物品
  """
  def remove_autoload(room, item_id) do
    {:ok, %{room | autoload: List.delete(room.autoload, item_id)}}
  end

  @doc """
  获取自动加载物品列表
  """
  def autoload(room), do: room.autoload
end
