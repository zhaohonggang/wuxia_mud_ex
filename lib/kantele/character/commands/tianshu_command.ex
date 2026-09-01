defmodule Kantele.Character.TianshuCommand do
  @moduledoc """
  天书命令：`tianshu [begin | select <编号> | status]`

  对应 LPC cmds/usr/tianshu.c（玩家侧命令层）。天书任务子系统（南贤打听、
  dating/renwu 交差、物品/尸体校验、bigreward 等）依赖缺失的 NPC 对话/物品/
  任务子系统，本期不迁移；仅落实命令层：
  - `tianshu`           查看当前在做/已完成的天书
  - `tianshu begin`     开始（或重做）当前选定的天书
  - `tianshu select <编号>`  选择一本天书（见 help）
  - `tianshu status`    查看 14 部天书收集状态

  完成状态落盘 `meta.tianshu_books`（`%{书名 => 1}`）。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.PlayerMeta

  @books %{
    "0" => "飞狐外传",
    "1" => "雪山飞狐",
    "2" => "连城决",
    "3" => "天龙八部",
    "4" => "射雕英雄传",
    "5" => "白马啸西风",
    "6" => "鹿鼎记",
    "7" => "笑傲江湖",
    "8" => "书剑恩仇录",
    "9" => "神雕侠侣",
    "a" => "侠客行",
    "b" => "倚天屠龙记",
    "c" => "碧血剑",
    "d" => "鸳鸯刀"
  }

  def run(conn, %{"arg" => arg}) do
    arg = String.trim(arg || "")

    case arg do
      "" ->
        status_current(conn)

      "begin" ->
        begin(conn)

      "status" ->
        status(conn)

      "select" ->
        select_prompt(conn)

      _ ->
        case String.split(arg, ~r/\s+/, parts: 2) do
          ["select", num] -> do_select(conn, num)
          _ -> render_msg(conn, "请用 help tianshu 查看帮助。\n")
        end
    end
  end

  def run(conn, %{}) do
    status_current(conn)
  end

  def run_bare(conn, %{}) do
    run(conn, %{})
  end

  defp status_current(conn) do
    meta = conn.character.meta
    current = PlayerMeta.get_temp(meta, "tianshu/current")
    books = PlayerMeta.tianshu_books(meta)

    cond do
      is_nil(current) ->
        render_msg(conn, "你现在没有天书的任务！\n")

      Map.has_key?(books, current) ->
        render_msg(conn, "你现在刚做完#{current}！\n")

      true ->
        render_msg(conn, "你目前该完成#{current}！\n")
    end
  end

  defp begin(conn) do
    meta = conn.character.meta
    current = PlayerMeta.get_temp(meta, "tianshu/current")
    books = PlayerMeta.tianshu_books(meta)

    if current do
      new_conn = put_character(conn, %{conn.character | meta: meta})

      new_conn
      |> render_msg(
        if Map.has_key?(books, current),
          do: "你开始重做#{current}了！\n",
          else: "你开始做天书了！\n"
      )
      |> prompt(CommandView, "prompt", %{})
    else
      render_msg(conn, "你还没有选择天书，请用 tianshu select <编号> 选择。\n")
    end
  end

  defp select_prompt(conn) do
    render_msg(
      conn,
      "请选择你要做的天书：\n" <>
        String.trim("""
        0.飞狐外传  1.雪山飞狐  2.连城决   3.天龙八部
        4.射雕英雄传 5.白马啸西风 6.鹿鼎记  7.笑傲江湖
        8.书剑恩仇录 9.神雕侠侣   a.侠客行   b.倚天屠龙记
        c.碧血剑    d.鸳鸯刀
        """) <>
        "\n例如：tianshu select 1\n"
    )
  end

  defp do_select(conn, num) do
    book = Map.get(@books, num)

    if book do
      meta = conn.character.meta
      meta = PlayerMeta.put_temp(meta, "tianshu/current", book)
      new_conn = put_character(conn, %{conn.character | meta: meta})

      new_conn
      |> render_msg("你决定开始做#{book}了。\n")
      |> save()
    else
      render_msg(conn, "对不起，您只能从（0,1,2,3...a,b,c,d）中选择。\n")
    end
  end

  defp status(conn) do
    books = PlayerMeta.tianshu_books(conn.character.meta)

    rows =
      @books
      |> Enum.map(fn {_num, name} -> [name, desc(books, name)] end)
      |> Enum.chunk_every(2)
      |> Enum.map_join("", fn chunk ->
        chunk
        |> Enum.map_join("", fn [_name, line] -> line end)
        |> Kernel.<>("\n")
      end)

    render_msg(conn, "天书收集状况：\n" <> rows)
  end

  defp desc(books, name) do
    mark = if Map.has_key?(books, name), do: "已完成", else: "未完成"
    String.pad_trailing("#{name}：#{mark}", 14)
  end

  defp render_msg(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  defp save(conn) do
    Kantele.Character.Records.save(conn.private.update_character || conn.character)
    conn
  end
end
