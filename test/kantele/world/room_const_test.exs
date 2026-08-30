defmodule Kantele.World.Room.ConstTest do
  use ExUnit.Case, async: true

  alias Kantele.World.Room.Const

  describe "constants" do
    test "max_item_in_room is 999" do
      assert Const.max_item_in_room() == 999
    end

    test "door states" do
      assert Const.door_closed() == 1
      assert Const.door_locked() == 2
      assert Const.door_smashed() == 4
    end

    test "room types" do
      assert Const.chat_room() == "/inherit/room/chatroom"
      assert Const.create_chat_room() == "/inherit/room/create"
      assert Const.producing_room() == "/inherit/room/producing"
      assert Const.trans_room() == "/inherit/room/trans"
    end
  end
end
