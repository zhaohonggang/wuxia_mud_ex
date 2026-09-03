defmodule Kantele.Character.FemoteCommand do
  @moduledoc """
  女性表情查询命令：`femote <关键字>`

  对应 LPC cmds/std/femote.c。
  搜索包含指定关键字的 emote 动作。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, %{"keyword" => keyword}) do
    results = search_emotes(keyword)

    if results == [] do
      conn
      |> render(CommandView, "text", %{text: "没有找到包含该关键字的 emote。\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      text = format_results(keyword, results)
      conn
      |> render(CommandView, "text", %{text: text})
      |> prompt(CommandView, "prompt", %{})
    end
  end

  def run(conn, %{}) do
    conn
    |> render(CommandView, "text", %{text: help_text()})
    |> prompt(CommandView, "prompt", %{})
  end

  defp search_emotes(keyword) do
    all_emotes()
    |> Enum.filter(fn emote ->
      String.contains?(emote.description, keyword) ||
        String.contains?(emote.name, keyword)
    end)
  end

  defp all_emotes do
    [
      %{name: "wave", description: "挥了挥手", who: "你挥了挥手。", others: "~n挥了挥手。"},
      %{name: "smile", description: "微微一笑", who: "你微微一笑。", others: "~n微微一笑。"},
      %{name: "laugh", description: "大声笑了起来", who: "你大声笑了起来。", others: "~n大声笑了起来。"},
      %{name: "cry", description: "放声痛哭", who: "你放声痛哭。", others: "~n放声痛哭。"},
      %{name: "sigh", description: "叹了口气", who: "你叹了口气。", others: "~n叹了口气。"},
      %{name: "nod", description: "点了点头", who: "你点了点头。", others: "~n点了点头。"},
      %{name: "blush", description: "脸红了", who: "你脸红了。", others: "~n脸红了。"},
      %{name: "think", description: "陷入沉思", who: "你陷入沉思。", others: "~n陷入沉思。"},
      %{name: "flinch", description: "畏缩了一下", who: "你畏缩了一下。", others: "~n畏缩了一下。"},
      %{name: "dance", description: "翩翩起舞", who: "你翩翩起舞。", others: "~n翩翩起舞。"}
    ]
  end

  defp format_results(keyword, results) do
    count = length(results)
    header = "\n查询结果\n------------------------------------------------------------\n"

    items =
      results
      |> Enum.map(fn emote ->
        "动作: #{emote.description}\n"
      end)
      |> Enum.join()

    footer = "------------------------------------------------------------\n在武林外传中，包含\"#{keyword}\"的 emote 共有 #{count} 个。\n"

    header <> items <> footer
  end

  defp help_text do
    """
    指令格式 : femote <关键字>
    功能：列出目前所有含指定关键字的 emote。比如：

    femote *飞起一脚，正好踢中*的*
    或者
    femote 飞起

    只要匹配到了femote指定的关键字，即返回一个结果。
    """
  end
end
