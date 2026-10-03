defmodule Kantele.RoomChannel do
  use Kalevala.Communication.Channel

  @impl true
  def subscribe_request(_channel_name, options, config) do
    case config[:room_id] == options[:character].room_id do
      true ->
        :ok

      false ->
        {:error, :not_in_room}
    end
  end

  @impl true
  def unsubscribe_request(_channel_name, options, config) do
    case config[:room_id] != options[:character].room_id do
      true ->
        :ok

      false ->
        {:error, :in_room}
    end
  end

  @impl true
  def publish_request(_channel_name, _event, options, config) do
    # `options[:character]` 只在「玩家自己发消息」时才有。
    #
    # 系统广播（`Kantele.Communication.announce/2`，例如 Feature.Damage 的
    # 「XX晕倒了。」）是 `publish(channel, event, [])` —— options 是空的，
    # 发起者是 `system_character()`（一个裸 map，没有 room_id）。
    # 原来直接 `options[:character].room_id` 会抛
    # ** (UndefinedFunctionError) nil.room_id/0 is undefined，
    # 把房间频道进程和调用方（玩家进程）一起带崩 ——
    # 八卦阵「震」方向昏厥时的 announce 就撞上了这个。
    #
    # 系统广播没有「是否在自己房间」的语义，直接放行。
    case options[:character] do
      nil ->
        :ok

      character ->
        case config[:room_id] == character.room_id do
          true -> :ok
          false -> {:error, :not_in_room}
        end
    end
  end
end
