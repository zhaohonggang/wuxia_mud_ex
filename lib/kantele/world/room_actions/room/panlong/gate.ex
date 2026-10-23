defmodule Kantele.World.RoomActions.Room.Panlong.Gate do
  @moduledoc """
  盘龙居「前庭」<->「走道」双向木门（d/room/panlong/qianting.c + zoudao.c）。

  LPC 以 `gate` 标记配合 set/delete("exits/...") 控制，前庭 north <-> 走道 south，
  推门开门（10 秒后自动关门），关门关上。本引擎以出口存在与否作为门状态：
  前庭 `north` 与 走道 `south` 始终同步开关。两房均无常驻 NPC，故 LPC 中的
  `saodi laopu` / `is_owner` 分支在此不触发，保持与 LPC 推/关文案一致即可。

  定时器以 `room:qianting` 为所有者，两边推门共用同一个定时器键，重开前先取消。
  """

  alias Kantele.World.Room
  alias Kantele.World.RoomActions.DynamicExit
  alias Kantele.World.RoomActions.Helpers

  @owner_room_id "room:qianting"
  @timer_key "exit_timer:panlong:gate"

  @doc """
  打开双向大门：前庭 north -> 走道，走道 south -> 前庭，并登记 10s 自动关门。
  返回 `{conn, :opened}` 或 `{conn, :already_open}`。
  """
  def open_gate(
        conn,
        self_room,
        neighbor_room,
        self_dir,
        neighbor_dir,
        self_vision,
        neighbor_vision
      ) do
    cond do
      DynamicExit.open?(self_room, self_dir) ->
        {conn, :already_open}

      true ->
        conn =
          conn
          |> DynamicExit.open(self_room, self_dir, neighbor_room, self_vision)

        Room.set_exit(neighbor_room, neighbor_dir, self_room)

        if is_binary(neighbor_vision) and neighbor_vision != "" do
          Room.tell_room(%Room{id: neighbor_room}, neighbor_vision)
        end

        DynamicExit.close_after(
          10_000,
          @owner_room_id,
          @timer_key,
          [
            {self_room, self_dir, nil},
            {neighbor_room, neighbor_dir, nil}
          ]
        )

        {conn, :opened}
    end
  end

  @doc """
  关闭双向大门，并取消未触发的自动关门定时器。
  返回 `{conn, :closed}` 或 `{conn, :already_closed}`。
  """
  def close_gate(
        conn,
        self_room,
        neighbor_room,
        self_dir,
        neighbor_dir,
        self_vision,
        neighbor_vision
      ) do
    cond do
      not DynamicExit.open?(self_room, self_dir) ->
        {conn, :already_closed}

      true ->
        DynamicExit.cancel_close(@owner_room_id, @timer_key)

        conn = DynamicExit.close(conn, self_room, self_dir, self_vision)
        Room.delete_exit(neighbor_room, neighbor_dir)

        if is_binary(neighbor_vision) and neighbor_vision != "" do
          Room.tell_room(%Room{id: neighbor_room}, neighbor_vision)
        end

        {conn, :closed}
    end
  end
end
