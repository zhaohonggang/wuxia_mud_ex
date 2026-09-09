defmodule Kantele.World.Story.Gift do
  @moduledoc """
  剧情赠礼（对应 storyd.c 的 `give_gift/3`）

  - `random_player/1`：在在线玩家中随机抽一个（可选 `filter/1` 排除）；
  - `drop_to_room/3`：把指定物品实例放进房间 `item_instances`（地面可 `get`），
    并向房间内 `tell_room` 一句；
  - `drop_to_random_room/3`：抽一个随机玩家所在房间执行掉落。
  """

  require Logger

  alias Kantele.Character.Presence
  alias Kantele.World.Room

  @doc "在线玩家列表（Presence 中的角色结构）"
  def online_players() do
    Presence.characters()
  end

  @doc "随机在线玩家；过滤条件返回 false 的排除；无人可选返回 nil"
  def random_player(filter \\ fn _player -> true end) do
    Presence.characters()
    |> Enum.filter(filter)
    |> Enum.take_random(1)
    |> List.first()
  end

  @doc "把 `item_id` 物品落到 `room_id` 地上，并向房间发 `tell_msg`"
  def drop_to_room(room_id, item_id, tell_msg \\ "") do
    with {:ok, instance} <- build_instance(item_id),
         {:ok, room_pid} <- room_pid(room_id),
         :ok <- append_to_room(room_pid, instance) do
      if tell_msg != "" do
        Room.tell_room(%Room{id: room_id}, tell_msg)
      end

      :ok
    else
      other -> other
    end
  end

  @doc "随机抽一个在线玩家，把物品落到其所在房间；返回 `{:ok, player} | :none`"
  def drop_to_random_room(item_id, tell_msg, filter \\ fn _player -> true end) do
    case random_player(filter) do
      nil ->
        :none

      player ->
        case drop_to_room(player.room_id, item_id, tell_msg) do
          :ok -> {:ok, player}
          {:error, reason} -> {:error, reason, player}
        end
    end
  end

  defp build_instance(item_id) do
    instance = %Kalevala.World.Item.Instance{
      id: Kalevala.World.Item.Instance.generate_id(),
      item_id: item_id,
      created_at: DateTime.utc_now()
    }

    {:ok, instance}
  rescue
    e -> {:error, {:build_instance, e}}
  end

  defp room_pid(room_id) do
    case :global.whereis_name(Kalevala.World.Room.global_name(room_id)) do
      nil -> {:error, {:room_not_running, room_id}}
      :undefined -> {:error, {:room_not_running, room_id}}
      pid -> {:ok, pid}
    end
  end

  defp append_to_room(room_pid, instance) do
    room = :sys.get_state(room_pid)
    instances = get_in(room, [:private, :item_instances]) || []

    Kalevala.World.Room.update_items(room_pid, instances ++ [instance])
    :ok
  rescue
    e ->
      Logger.warn("story gift drop failed - #{inspect(e)}")
      {:error, {:append_to_room, e}}
  catch
    :exit, reason ->
      Logger.warn("story gift drop failed (exit) - #{inspect(reason)}")
      {:error, {:append_to_room_exit, reason}}
  end
end