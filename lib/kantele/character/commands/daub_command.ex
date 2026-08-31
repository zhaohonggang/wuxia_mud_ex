defmodule Kantele.Character.DaubCommand do
  @moduledoc """
  涂抹命令：`daub`

  对应 LPC cmds/std/daub.c
  涂抹毒药。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, %{"rest" => _rest}) do
    conn
    |> render(CommandView, "text", %{text: "涂抹系统暂未开放。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  def run(conn, %{}) do
    conn
    |> render(CommandView, "text", %{text: "你要往哪儿涂抹毒药？\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
