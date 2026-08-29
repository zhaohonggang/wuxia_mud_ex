defmodule Kantele.Character.QuestCommand do
  @moduledoc """
  任务进度：`quest` / `任务` / `myquest`

  用 `Kantele.Quest`（移植 CORE_USER_QUEST）展示玩家任务进度表：
  - **在办任务** + 击杀/收集进度（`get_todo`）
  - **已完成任务** 列表（`get_solved`）

  对照 LPC `cmds/usr/quest.c` 的查询展示层。任务完成由
  `QuestEvent.turnin_request` 写入 `set_solved`；在办进度待任务派发引擎
  （QUEST_D）接入后经 `set_todo`/`add_killed`/`add_item` 填充。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.PlayerMeta
  alias Kantele.Quest

  def run(conn, _params) do
    quests = PlayerMeta.quests(conn.character.meta)

    conn
    |> render(CommandView, "text", %{text: format(quests)})
    |> prompt(CommandView, "prompt", %{})
  end

  @doc "格式化任务进度表"
  def format(quests) do
    header = "你的任务记录\n"
    separator = "≡------------------------------------------------------------≡\n"
    body = format_in_progress(quests) <> format_solved(quests)

    if body == "" do
      header <> separator <> "    你目前没有任何任务记录。\n" <> separator
    else
      header <> separator <> body <> separator
    end
  end

  # 在办任务 + 击杀/收集进度
  defp format_in_progress(quests) do
    case Quest.get_todo_list(quests) do
      todo when map_size(todo) == 0 ->
        ""

      todo ->
        lines =
          for {quest_file, task} <- Enum.sort_by(todo, fn {k, _} -> k end) do
            "  ● #{quest_file}\n" <>
              format_counts(Map.get(task, :killed, %{}), "击杀") <>
              format_counts(Map.get(task, :item, %{}), "收集")
          end

        "  在办任务（#{map_size(todo)}）\n" <> Enum.join(lines)
    end
  end

  # 已完成任务
  defp format_solved(quests) do
    case Quest.get_solved(quests) do
      [] ->
        ""

      solved ->
        lines = Enum.map_join(solved, fn f -> "  ○ #{f}\n" end)
        "  已完成任务（#{length(solved)}）\n" <> lines
    end
  end

  # 击杀/收集计数：只列出 > 0 的项（LPC 列表里 >0 才显示）
  defp format_counts(counts, label) when is_map(counts) do
    rows =
      counts
      |> Enum.reject(fn {_k, v} -> v == 0 end)
      |> Enum.map(fn {k, v} -> "#{k} x#{v}" end)

    case rows do
      [] -> ""
      rows -> "      #{label}：#{Enum.join(rows, " ")}\n"
    end
  end

  defp format_counts(_, _label), do: ""
end