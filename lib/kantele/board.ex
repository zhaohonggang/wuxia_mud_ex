defmodule Kantele.Board do
  @moduledoc """
  通用公告板系统（对应 LPC inherit/misc/fboard.c 和 jboard.c）

  提供只读公告板功能：
  - read: 读取留言
  - list: 列出所有留言
  - 未读计数

  与 Bboard 的区别：不允许发布/删除，只有读取功能。

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
  """

  @doc """
  创建只读公告板
  """
  def new(board_id, opts \\ []) do
    %{
      board_id: board_id,
      notes: [],
      capacity: Keyword.get(opts, :capacity, 100),
      read_only: true
    }
  end

  @doc """
  添加留言（仅用于初始化，不允许用户发布）
  """
  def add_note(board, note) do
    notes = board.notes ++ [note]
    %{board | notes: notes}
  end

  @doc """
  读取留言
  """
  def read(board, index) when is_integer(index) do
    notes = board.notes
    zero_index = index - 1

    if zero_index < 0 or zero_index >= length(notes) do
      {:error, :not_found}
    else
      {:ok, Enum.at(notes, zero_index)}
    end
  end

  @doc """
  获取未读数量
  """
  def unread_count(board, last_read_time) when is_integer(last_read_time) do
    Enum.count(board.notes, fn n -> n.time > last_read_time end)
  end

  @doc """
  获取所有留言
  """
  def list_notes(board), do: board.notes

  @doc """
  获取留言数量
  """
  def count(board), do: length(board.notes)

  @doc """
  检查是否为空
  """
  def empty?(board), do: board.notes == []

  @doc """
  按时间排序（降序，最新的在前）
  """
  def sorted_by_time(board, order \\ :desc) do
    sorter = if order == :desc, do: &(&1.time >= &2.time), else: &(&1.time <= &2.time)
    %{board | notes: Enum.sort(board.notes, sorter)}
  end

  @doc """
  过滤留言
  """
  def filter_notes(board, predicate) when is_function(predicate, 1) do
    %{board | notes: Enum.filter(board.notes, predicate)}
  end
end
