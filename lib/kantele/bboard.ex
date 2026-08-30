defmodule Kantele.Bboard do
  @moduledoc """
  公告板系统（对应 LPC inherit/misc/bboard.c）

  提供留言板功能：
  - post: 发布留言
  - read: 读取留言
  - discard: 删除留言
  - 持久化存储

  ## 数据结构

  留言格式：
  ```
  %{
    title: string,
    author: string,
    time: integer,
    msg: string
  }
  ```

  留言板格式：
  ```
  %{
    board_id: string,
    notes: [note, ...],
    capacity: integer
  }
  ```
  """

  @default_capacity 50

  @doc """
  创建新留言板
  """
  def new(board_id, opts \\ []) do
    %{
      board_id: board_id,
      notes: [],
      capacity: Keyword.get(opts, :capacity, @default_capacity)
    }
  end

  @doc """
  发布留言（对应 do_post）

  返回 `{:ok, new_board}` 或 `{:error, reason}`
  """
  def post(board, title, author) when is_map(board) and is_binary(title) do
    title = String.trim(title)
    title = if title == "", do: "无标题", else: title

    note = %{
      title: title,
      author: author,
      time: System.system_time(:second),
      msg: ""
    }

    notes = board.notes ++ [note]
    board = %{board | notes: notes}

    {:ok, board}
  end

  @doc """
  完成留言编辑（对应 done_post）
  """
  def finish_post(board, note_index, msg) when is_map(board) and is_integer(note_index) do
    notes = board.notes

    if note_index < 0 or note_index >= length(notes) do
      {:error, :invalid_index}
    else
      note = Enum.at(notes, note_index)
      note = Map.put(note, :msg, msg)
      notes = List.replace_at(notes, note_index, note)
      board = %{board | notes: notes}

      {:ok, board}
    end
  end

  @doc """
  读取留言（对应 do_read）

  返回 `{:ok, note}` 或 `{:error, reason}`
  """
  def read(board, index) when is_map(board) and is_integer(index) do
    notes = board.notes
    zero_index = index - 1

    if zero_index < 0 or zero_index >= length(notes) do
      {:error, :not_found}
    else
      {:ok, Enum.at(notes, zero_index)}
    end
  end

  @doc """
  读取最新未读留言（对应 do_read "new"）
  """
  def read_new(board, last_read_time) when is_map(board) and is_integer(last_read_time) do
    notes = board.notes

    case Enum.find_index(notes, fn n -> n.time > last_read_time end) do
      nil -> {:error, :no_new}
      index -> {:ok, Enum.at(notes, index), index + 1}
    end
  end

  @doc """
  删除留言（对应 do_discard）

  返回 `{:ok, new_board}` 或 `{:error, reason}`
  """
  def discard(board, index, author) when is_map(board) and is_integer(index) do
    notes = board.notes
    zero_index = index - 1

    if zero_index < 0 or zero_index >= length(notes) do
      {:error, :not_found}
    else
      note = Enum.at(notes, zero_index)

      if note.author != author do
        {:error, :not_owner}
      else
        notes = List.delete_at(notes, zero_index)
        board = %{board | notes: notes}
        {:ok, board}
      end
    end
  end

  @doc """
  获取未读留言数
  """
  def unread_count(board, last_read_time) when is_map(board) and is_integer(last_read_time) do
    Enum.count(board.notes, fn n -> n.time > last_read_time end)
  end

  @doc """
  检查留言板是否为空
  """
  def empty?(board), do: board.notes == []

  @doc """
  获取留言数量
  """
  def count(board), do: length(board.notes)

  @doc """
  截断超过容量的旧留言（对应 BOARD_CAPACITY）
  """
  def prune(board) do
    capacity = board.capacity
    notes = board.notes

    if length(notes) > capacity do
      keep = div(capacity, 2)
      notes = Enum.take(notes, -keep)
      {:ok, %{board | notes: notes}}
    else
      {:ok, board}
    end
  end
end
