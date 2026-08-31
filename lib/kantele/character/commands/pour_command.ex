defmodule Kantele.Character.PourCommand do
  @moduledoc """
  下毒命令：`pour`

  对应 LPC cmds/std/pour.c
  向容器中下毒。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, %{"rest" => _rest}) do
    conn
    |> render(CommandView, "text", %{text: "下毒系统暂未开放。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  def run(conn, %{}) do
    conn
    |> render(CommandView, "text", %{text: "你要往哪里下毒？\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
