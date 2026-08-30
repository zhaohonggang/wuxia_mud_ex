defmodule Kantele.Character.NewsCommand do
  @moduledoc """
  新闻命令：`news [编号|new|all]`

  对应 LPC cmds/usr/news.c
  阅读游戏新闻。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, %{"action" => action, "arg" => arg}) do
    conn
    |> render(CommandView, "text", %{text: "新闻系统暂未开放。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  def run(conn, %{"number" => _number}) do
    conn
    |> render(CommandView, "text", %{text: "新闻系统暂未开放。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  def run(conn, %{}) do
    conn
    |> render(CommandView, "text", %{text: "新闻系统暂未开放。\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
