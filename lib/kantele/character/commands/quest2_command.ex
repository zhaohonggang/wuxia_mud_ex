defmodule Kantele.Character.Quest2Command do
  @moduledoc """
  任务日志命令：`quest2 [<编号> | <编号> -d | -s | <编号> -s]`

  对应 LPC cmds/usr/quest2.c（玩家侧；巫师分支依赖 P4 管理员框架，未迁移）：
  - `quest2`          列出在办任务列表
  - `quest2 <编号>`    显示某个在办任务的进度
  - `quest2 <编号> -d` 放弃某个在办任务
  - `quest2 -s`        列出已解决任务
  - `quest2 <编号> -s` 显示某个已解决任务
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.PlayerMeta
  alias Kantele.Quest

  def run(conn, %{"arg" => arg}) do
    arg = String.trim(arg || "")

    case parse_arg(arg) do
      :list -> list(conn)
      {:detail, index} -> detail(conn, index)
      {:giveup, index} -> giveup(conn, index)
      :solved -> list_solved(conn)
      {:solved_detail, index} -> solved_detail(conn, index)
      :error -> render_msg(conn, "非法的参数。\n")
    end
  end

  def run(conn, %{}) do
    list(conn)
  end

  def run_bare(conn, %{}) do
    run(conn, %{})
  end

  defp parse_arg(""), do: :list

  defp parse_arg(arg) do
    case String.split(arg, ~r/\s+/, parts: 2) do
      ["-s"] ->
        :solved

      ["-s", index] ->
        case Integer.parse(index) do
          {n, ""} when n >= 1 -> {:solved_detail, n}
          _ -> :error
        end

      [index, "-d"] ->
        case Integer.parse(index) do
          {n, ""} when n >= 1 -> {:giveup, n}
          _ -> :error
        end

      [index] ->
        case Integer.parse(index) do
          {n, ""} when n >= 1 -> {:detail, n}
          _ -> :error
        end

      _ ->
        :error
    end
  end

  defp list(conn) do
    todo = todo_list(conn.character.meta)

    if map_size(todo) == 0 do
      render_msg(conn, "你目前没有接受任何任务。\n")
    else
      rows =
        todo
        |> Enum.with_index(1)
        |> Enum.map_join("", fn {{file, progress}, i} ->
          "#{pad(i)}#{file}#{progress_str(progress)}\n"
        end)

      render_msg(conn, "笑傲江湖·任务日志（#{map_size(todo)}/20）\n编号  任务\n" <> rows)
    end
  end

  defp detail(conn, index) do
    todo = todo_list(conn.character.meta)

    case idx_task(todo, index) do
      nil ->
        render_msg(conn, "你要看哪一个编号的任务？\n")

      {file, progress} ->
        kill_str = build_progress(:killed, progress)
        item_str = build_progress(:item, progress)

        text =
          "任务：#{file}\n" <>
            "需求：\n" <>
            kill_str <>
            item_str <>
            (if kill_str == "" and item_str == "", do: "  （无具体击杀/收集要求）\n", else: "") <>
            "任务奖励：完成任务后返回任务发布人处领取。\n"

        render_msg(conn, text)
    end
  end

  defp giveup(conn, index) do
    todo = todo_list(conn.character.meta)

    case idx_task(todo, index) do
      nil ->
        render_msg(conn, "你要放弃哪一个编号的任务？\n")

      {file, _progress} ->
        new_quests = Quest.del_todo(PlayerMeta.quests(conn.character.meta), file)
        meta = PlayerMeta.put_quests(conn.character.meta, new_quests)
        new_conn = put_character(conn, %{conn.character | meta: meta})

        new_conn
        |> render_msg("你放弃了 #{file} 任务。\n")
        |> save()
    end
  end

  defp list_solved(conn) do
    solved = PlayerMeta.quests(conn.character.meta) |> Quest.get_solved()

    if solved == [] do
      render_msg(conn, "你目前还没有解决任何任务。\n")
    else
      rows =
        solved
        |> Enum.with_index(1)
        |> Enum.map_join("", fn {file, i} -> "#{pad(i)}#{file}\n" end)

      render_msg(conn, "已完成的任务列表（#{length(solved)}）\n编号  任务\n" <> rows)
    end
  end

  defp solved_detail(conn, index) do
    solved = PlayerMeta.quests(conn.character.meta) |> Quest.get_solved()

    case Enum.at(solved, index - 1) do
      nil ->
        render_msg(conn, "你要看哪一个编号的任务？\n")

      file ->
        render_msg(conn, "任务：#{file}\n奖励：已领取。\n")
    end
  end

  defp todo_list(meta), do: meta |> PlayerMeta.quests() |> Quest.get_todo_list()

  defp idx_task(todo, index), do: Enum.at(Enum.to_list(todo), index - 1)

  defp build_progress(kind, progress) do
    progress
    |> Map.get(kind, %{})
    |> Enum.reject(fn {_k, count} -> count == 0 end)
    |> case do
      [] ->
        ""

      entries ->
        header = if kind == :killed, do: "已杀死：\n", else: "已取得：\n"

        header <>
          Enum.map_join(entries, "", fn {name, count} ->
            "  #{name}： #{count}\n"
          end)
    end
  end

  defp progress_str(progress) do
    parts =
      [:killed, :item]
      |> Enum.map(fn kind -> build_progress(kind, progress) |> String.trim() end)
      |> Enum.reject(&(&1 == ""))

    case parts do
      [] -> ""
      _ -> "  [" <> Enum.join(parts, " ") <> "]"
    end
  end

  defp pad(i), do: String.pad_leading("#{i}", 4)

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
