defmodule Kantele.PrivateRoomTest do
  use ExUnit.Case, async: true

  alias Kantele.PrivateRoom

  describe "new/2" do
    test "creates private room with owner" do
      room = PrivateRoom.new("player1")
      assert room.room_owner_id == "player1"
      assert room.door_state == PrivateRoom.door_closed()
    end
  end

  describe "room_owner?/2" do
    test "owner can access" do
      room = PrivateRoom.new("player1")
      assert PrivateRoom.room_owner?(room, "player1") == true
      assert PrivateRoom.room_owner?(room, "player2") == false
    end
  end

  describe "door operations" do
    test "owner can open door" do
      room = PrivateRoom.new("player1")
      assert {:ok, room} = PrivateRoom.open_door(room, "player1")
      assert PrivateRoom.open?(room)
    end

    test "non-owner cannot open door" do
      room = PrivateRoom.new("player1")
      assert PrivateRoom.open_door(room, "player2") == {:error, :not_owner_or_locked}
    end

    test "owner can close door" do
      room = PrivateRoom.new("player1")
      {:ok, room} = PrivateRoom.open_door(room, "player1")
      assert {:ok, room} = PrivateRoom.close_door(room, "player1")
      refute PrivateRoom.open?(room)
    end

    test "owner can lock door" do
      room = PrivateRoom.new("player1")
      assert {:ok, room} = PrivateRoom.lock(room, "player1")
      assert PrivateRoom.locked?(room)
    end

    test "owner can unlock door" do
      room = PrivateRoom.new("player1")
      {:ok, room} = PrivateRoom.lock(room, "player1")
      assert {:ok, room} = PrivateRoom.unlock(room, "player1")
      refute PrivateRoom.locked?(room)
    end
  end

  describe "set_short/3" do
    test "owner can set short" do
      room = PrivateRoom.new("player1")
      assert {:ok, room} = PrivateRoom.set_short(room, "新房间", "player1")
      assert room.short == "新房间"
    end

    test "non-owner cannot set short" do
      room = PrivateRoom.new("player1")
      assert PrivateRoom.set_short(room, "新房间", "player2") == {:error, :not_owner}
    end
  end

  describe "autoload" do
    test "add autoload item" do
      room = PrivateRoom.new("player1")
      assert {:ok, room} = PrivateRoom.add_autoload(room, "item_id_1")
      assert "item_id_1" in room.autoload
    end

    test "remove autoload item" do
      room = PrivateRoom.new("player1", autoload: ["item_id_1"])
      assert {:ok, room} = PrivateRoom.remove_autoload(room, "item_id_1")
      assert "item_id_1" not in room.autoload
    end
  end
end
