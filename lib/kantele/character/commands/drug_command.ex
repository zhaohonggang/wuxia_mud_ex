defmodule Kantele.Character.DrugCommand do
  @moduledoc """
  下毒命令：`drug`

  对应 LPC cmds/std/drug.c
  向食物中下毒。
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
