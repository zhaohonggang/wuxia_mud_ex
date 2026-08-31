defmodule Kantele.Character.TouchCommand do
  @moduledoc """
  触摸命令：`touch`

  对应 LPC cmds/std/touch.c
  触摸物品。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, %{"item" => _item}) do
    conn
    |> render(CommandView, "text", %{text: "触摸系统暂未开放。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  def run(conn, %{}) do
    conn
    |> render(CommandView, "text", %{text: "你要触摸什么物品？\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
