defmodule Kantele.Character.QuestCommand do
  @moduledoc """
  任务命令：`quest`

  对应 LPC cmds/usr/quest.c
  显示任务进度。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Quest

  def run(conn, _params) do
    quests = conn.character.meta.quests

    todo = Quest.get_todo_list(quests)
    solved = Quest.get_solved(quests)

    text =
      cond do
        map_size(todo) == 0 and solved == [] ->
          "没有任何任务记录。\n"

        true ->
          build_quest_display(todo, solved)
      end

    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  defp build_quest_display(todo, solved) do
    lines = []

    (if map_size(todo) > 0 do
       lines ++ ["在办任务（#{map_size(todo)}）", build_todo_list(todo)]
     else
       lines
     end ++
       if solved != [] do
         ["已完成任务（#{length(solved)}）", build_solved_list(solved)]
       else
         []
       end)
    |> Enum.join("\n")
  end

  defp build_todo_list(todo) do
    Enum.map_join(todo, "", fn {file, progress} ->
      kill_str = build_kill_progress(progress)
      item_str = build_item_progress(progress)
      "#{file}#{kill_str}#{item_str}\n"
    end)
  end

  defp build_kill_progress(%{killed: killed_map}) do
    killed_map
    |> Enum.reject(fn {_enemy, count} -> count == 0 end)
    |> case do
      [] ->
        ""

      kills ->
        " [" <> Enum.map_join(kills, ", ", fn {enemy, count} -> "#{enemy} x#{count}" end) <> "]"
    end
  end

  defp build_kill_progress(_), do: ""

  defp build_item_progress(%{item: item_map}) do
    item_map
    |> Enum.reject(fn {_item, count} -> count == 0 end)
    |> case do
      [] ->
        ""

      items ->
        " [" <> Enum.map_join(items, ", ", fn {item, count} -> "#{item} x#{count}" end) <> "]"
    end
  end

  defp build_item_progress(_), do: ""

  defp build_solved_list(solved) do
    solved
    |> Enum.map(fn file -> file end)
    |> Enum.join(", ")
  end
end
