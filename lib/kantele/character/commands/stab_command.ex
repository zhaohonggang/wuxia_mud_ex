defmodule Kantele.Character.StabCommand do
  @moduledoc """
  插命令：`stab`

  对应 LPC cmds/std/stab.c
  将物品插在地上。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, %{"item" => _item}) do
    conn
    |> render(CommandView, "text", %{text: "插命令暂未开放。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  def run(conn, %{}) do
    conn
    |> render(CommandView, "text", %{text: "你要用什么物品？\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
