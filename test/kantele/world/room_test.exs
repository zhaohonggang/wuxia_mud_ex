defmodule Kantele.World.RoomTest do
  use ExUnit.Case, async: false

  alias Kantele.World.Room

  defp fresh_room_channel() do
    room_id = "t0-room-#{System.unique_integer([:positive])}"
    :ok = Kantele.Communication.register("rooms:#{room_id}", Kantele.RoomChannel, room_id: room_id)
    room_id
  end

  # 生产路径由 Conn.subscribe 注入 character，这里手动对齐
  defp subscribe_options(room_id) do
    [character: %Kalevala.Character{id: "t0-player", room_id: room_id}]
  end

  test "present/living 真实返回订阅房间频道的在线玩家（Q2-T0）" do
    room_id = fresh_room_channel()
    :ok = Kantele.Communication.subscribe("rooms:#{room_id}", subscribe_options(room_id))
    room = %Room{id: room_id}

    assert Room.present(room) == [self()]
    assert Room.living(room) == [self()]
  end

  test "tell_room 向房间内真实玩家投递广播（Q2-T0）" do
    room_id = fresh_room_channel()
    :ok = Kantele.Communication.subscribe("rooms:#{room_id}", subscribe_options(room_id))

    Room.tell_room(%Room{id: room_id}, "测试广播")

    assert_receive {:room_message, "测试广播"}
  end
end