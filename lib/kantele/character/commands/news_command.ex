defmodule Kantele.Character.NewsCommand do
  @moduledoc """
  新闻命令：`news [编号|new|all]`

  对应 LPC cmds/usr/news.c。
  阅读游戏新闻。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, %{"arg" => arg}) do
    case String.trim(arg || "") do
      "" ->
        show_news_list(conn)

      "new" ->
        show_news_new(conn)

      "all" ->
        show_news_all(conn)

      number when is_binary(number) ->
        case Integer.parse(number) do
          {n, _} -> show_news_number(conn, n)
          :error -> show_news_help(conn)
        end

      _ ->
        show_news_help(conn)
    end
  end

  def run(conn, %{}) do
    show_news_list(conn)
  end

  defp show_news_list(conn) do
    conn
    |> render(CommandView, "text", %{
      text: "游戏新闻（使用 news new 查看最新，news all 查看全部）：\n\n暂无新闻。\n"
    })
    |> prompt(CommandView, "prompt", %{})
  end

  defp show_news_new(conn) do
    conn
    |> render(CommandView, "text", %{text: "暂无最新新闻。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp show_news_all(conn) do
    conn
    |> render(CommandView, "text", %{text: "暂无新闻。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp show_news_number(conn, number) do
    conn
    |> render(CommandView, "text", %{text: "第#{number}号新闻不存在。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp show_news_help(conn) do
    conn
    |> render(CommandView, "text", %{text: "指令格式：news [编号|new|all]\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
