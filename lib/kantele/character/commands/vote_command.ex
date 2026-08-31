defmodule Kantele.Character.VoteCommand do
  @moduledoc """
  投票命令：`vote`

  对应 LPC cmds/std/vote.c
  投票系统。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, %{"rest" => _rest}) do
    conn
    |> render(CommandView, "text", %{text: "投票系统暂未开放。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  def run(conn, %{}) do
    conn
    |> render(CommandView, "text", %{text: "这神圣的一票，要想清楚了才能投。\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
