defmodule Kantele.BboardTest do
  use ExUnit.Case, async: true

  alias Kantele.Bboard

  describe "new/2" do
    test "creates empty board with default capacity" do
      board = Bboard.new("test_board")
      assert board.board_id == "test_board"
      assert board.notes == []
      assert board.capacity == 50
    end

    test "creates board with custom capacity" do
      board = Bboard.new("test_board", capacity: 100)
      assert board.capacity == 100
    end
  end

  describe "post/3" do
    test "posts a new note" do
      board = Bboard.new("test_board")
      {:ok, board} = Bboard.post(board, "Test Title", "player-id")
      assert length(board.notes) == 1
      note = hd(board.notes)
      assert note.title == "Test Title"
      assert note.author == "player-id"
    end

    test "uses '无标题' for empty title" do
      board = Bboard.new("test_board")
      {:ok, board} = Bboard.post(board, "", "player-id")
      assert hd(board.notes).title == "无标题"
    end

    test "trims whitespace from title" do
      board = Bboard.new("test_board")
      {:ok, board} = Bboard.post(board, "  Title  ", "player-id")
      assert hd(board.notes).title == "Title"
    end
  end

  describe "read/2" do
    test "reads note by index" do
      board = Bboard.new("test_board")
      {:ok, board} = Bboard.post(board, "First", "player1")
      {:ok, board} = Bboard.post(board, "Second", "player2")

      {:ok, note} = Bboard.read(board, 1)
      assert note.title == "First"

      {:ok, note} = Bboard.read(board, 2)
      assert note.title == "Second"
    end

    test "returns error for invalid index" do
      board = Bboard.new("test_board")
      assert Bboard.read(board, 1) == {:error, :not_found}
      assert Bboard.read(board, 0) == {:error, :not_found}
    end
  end

  describe "read_new/2" do
    test "finds first unread note" do
      now = System.system_time(:second)

      # Build board directly with known times
      board = %{
        board_id: "test",
        notes: [
          %{title: "Old", author: "player1", time: now - 100, msg: ""},
          %{title: "New", author: "player2", time: now, msg: ""}
        ],
        capacity: 50
      }

      {:ok, note, index} = Bboard.read_new(board, now - 50)
      assert note.title == "New"
      assert index == 2
    end

    test "returns no_new when all read" do
      board = Bboard.new("test_board")
      {:ok, board} = Bboard.post(board, "Only", "player1")
      time = System.system_time(:second) + 1000

      assert Bboard.read_new(board, time) == {:error, :no_new}
    end
  end

  describe "discard/3" do
    test "deletes own note" do
      board = Bboard.new("test_board")
      {:ok, board} = Bboard.post(board, "To Delete", "player1")
      {:ok, board} = Bboard.discard(board, 1, "player1")
      assert Bboard.empty?(board)
    end

    test "returns error when not owner" do
      board = Bboard.new("test_board")
      {:ok, board} = Bboard.post(board, "To Delete", "player1")
      assert Bboard.discard(board, 1, "player2") == {:error, :not_owner}
    end

    test "returns error for invalid index" do
      board = Bboard.new("test_board")
      assert Bboard.discard(board, 1, "player1") == {:error, :not_found}
    end
  end

  describe "unread_count/2" do
    test "counts unread notes" do
      board = Bboard.new("test_board")
      {:ok, board} = Bboard.post(board, "First", "player1")

      Process.sleep(10)
      last_time = System.system_time(:second) - 1

      {:ok, _board} = Bboard.post(board, "Second", "player2")

      assert Bboard.unread_count(board, last_time) == 1
    end
  end

  describe "prune/1" do
    test "prunes old notes when over capacity" do
      board = Bboard.new("test_board", capacity: 10)
      # Post 20 notes
      {:ok, board} =
        Enum.reduce(1..20, {:ok, board}, fn i, {:ok, b} ->
          Bboard.post(b, "Note #{i}", "player")
        end)

      {:ok, pruned} = Bboard.prune(board)
      assert length(pruned.notes) == 5
    end

    test "keeps notes when under capacity" do
      board = Bboard.new("test_board", capacity: 10)
      {:ok, board} = Bboard.post(board, "Note 1", "player")

      {:ok, pruned} = Bboard.prune(board)
      assert length(pruned.notes) == 1
    end
  end
end
