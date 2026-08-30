defmodule Kantele.ChatroomTest do
  use ExUnit.Case, async: true

  alias Kantele.Chatroom

  describe "new/2" do
    test "creates chatroom with owner" do
      room = Chatroom.new("player1")
      assert room.owner_id == "player1"
      assert room.members == []
      assert room.secret == false
      assert room.ban_all == false
    end

    test "creates chatroom with couple" do
      room = Chatroom.new("player1", couple_id: "player2")
      assert room.couple_id == "player2"
    end
  end

  describe "owner?/2" do
    test "owner can manage" do
      room = Chatroom.new("player1")
      assert Chatroom.owner?(room, "player1") == true
      assert Chatroom.owner?(room, "player2") == false
    end

    test "couple can manage" do
      room = Chatroom.new("player1", couple_id: "player2")
      assert Chatroom.owner?(room, "player2") == true
    end
  end

  describe "banned?/2" do
    test "banned player is blocked" do
      room = %{Chatroom.new("player1") | ban: ["player2"]}
      assert Chatroom.banned?(room, "player2") == true
    end

    test "unbanned player is allowed" do
      room = Chatroom.new("player1")
      assert Chatroom.banned?(room, "player2") == false
    end
  end

  describe "ban_all mode" do
    test "blocks non-invited when ban_all is true" do
      room = %{Chatroom.new("player1") | ban_all: true, can: ["player2"]}
      assert Chatroom.banned?(room, "player2") == false
      assert Chatroom.banned?(room, "player3") == true
    end
  end

  describe "set_topic/3" do
    test "owner can set topic" do
      room = Chatroom.new("player1")
      assert {:ok, room} = Chatroom.set_topic(room, "今日话题", "player1")
      assert room.topic == "今日话题"
    end

    test "non-owner cannot set topic" do
      room = Chatroom.new("player1")
      assert Chatroom.set_topic(room, "话题", "player2") == {:error, :not_owner}
    end
  end

  describe "ban_player/3" do
    test "owner can ban player" do
      room = Chatroom.new("player1")
      assert {:ok, room} = Chatroom.ban_player(room, "player2", "player1")
      assert "player2" in room.ban
    end

    test "owner cannot ban self" do
      room = Chatroom.new("player1")
      assert Chatroom.ban_player(room, "player1", "player1") == {:error, :cannot_ban_self}
    end

    test "non-owner cannot ban" do
      room = Chatroom.new("player1")
      assert Chatroom.ban_player(room, "player2", "player2") == {:error, :not_owner}
    end
  end

  describe "unban_player/3" do
    test "owner can unban player" do
      room = %{Chatroom.new("player1") | ban: ["player2"]}
      assert {:ok, room} = Chatroom.unban_player(room, "player2", "player1")
      assert "player2" not in room.ban
    end
  end

  describe "join/leave" do
    test "player can join" do
      room = Chatroom.new("player1")
      assert {:ok, room} = Chatroom.join(room, "player2")
      assert "player2" in room.members
    end

    test "player can leave" do
      room = %{Chatroom.new("player1") | members: ["player2"]}
      assert {:ok, room} = Chatroom.leave(room, "player2")
      assert "player2" not in room.members
    end

    test "joining twice is idempotent" do
      room = Chatroom.new("player1")
      assert {:ok, room} = Chatroom.join(room, "player2")
      assert {:ok, room} = Chatroom.join(room, "player2")
      assert length(room.members) == 1
    end
  end

  describe "set_secret/3" do
    test "owner can set secret" do
      room = Chatroom.new("player1")
      assert {:ok, room} = Chatroom.set_secret(room, true, "player1")
      assert room.secret == true
    end

    test "non-owner cannot set secret" do
      room = Chatroom.new("player1")
      assert Chatroom.set_secret(room, true, "player2") == {:error, :not_owner}
    end
  end
end
