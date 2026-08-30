defmodule Kantele.BoardTest do
  use ExUnit.Case, async: true

  alias Kantele.Board

  describe "new/2" do
    test "creates read-only board" do
      board = Board.new("test_board")
      assert board.board_id == "test_board"
      assert board.read_only == true
      assert board.notes == []
    end
  end

  describe "add_note/2" do
    test "adds a note" do
      board = Board.new("test_board")
      note = %{title: "Test", author: "player1", time: 100, msg: "Hello"}
      board = Board.add_note(board, note)
      assert length(board.notes) == 1
    end
  end

  describe "read/2" do
    test "reads note by index" do
      board = Board.new("test_board")
      note = %{title: "Test", author: "player1", time: 100, msg: "Hello"}
      board = Board.add_note(board, note)

      {:ok, read_note} = Board.read(board, 1)
      assert read_note.title == "Test"
    end

    test "returns error for invalid index" do
      board = Board.new("test_board")
      assert Board.read(board, 1) == {:error, :not_found}
    end
  end

  describe "unread_count/2" do
    test "counts unread notes" do
      board = Board.new("test_board")
      board = Board.add_note(board, %{title: "Old", author: "p", time: 50, msg: ""})
      board = Board.add_note(board, %{title: "New", author: "p", time: 100, msg: ""})

      assert Board.unread_count(board, 75) == 1
    end
  end

  describe "sorted_by_time/2" do
    test "sorts descending by default" do
      board = Board.new("test_board")
      board = Board.add_note(board, %{title: "First", author: "p", time: 50, msg: ""})
      board = Board.add_note(board, %{title: "Second", author: "p", time: 100, msg: ""})

      sorted = Board.sorted_by_time(board)
      assert hd(sorted.notes).title == "Second"
    end

    test "sorts ascending" do
      board = Board.new("test_board")
      board = Board.add_note(board, %{title: "First", author: "p", time: 50, msg: ""})
      board = Board.add_note(board, %{title: "Second", author: "p", time: 100, msg: ""})

      sorted = Board.sorted_by_time(board, :asc)
      assert hd(sorted.notes).title == "First"
    end
  end

  describe "filter_notes/2" do
    test "filters by predicate" do
      board = Board.new("test_board")
      board = Board.add_note(board, %{title: "A", author: "p1", time: 50, msg: ""})
      board = Board.add_note(board, %{title: "B", author: "p2", time: 100, msg: ""})

      filtered = Board.filter_notes(board, fn n -> n.author == "p1" end)
      assert length(filtered.notes) == 1
      assert hd(filtered.notes).title == "A"
    end
  end
end
