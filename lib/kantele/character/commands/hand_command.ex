defmodule Kantele.Character.HandCommand do
  @moduledoc """
  手持命令：`hand`

  对应 LPC cmds/std/hand.c
  拿出物品握在手中。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, %{"item" => _item}) do
    conn
    |> render(CommandView, "text", %{text: "手持系统暂未开放。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  def run(conn, %{}) do
    conn
    |> render(CommandView, "text", %{text: "你要拿出什么东西？\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
