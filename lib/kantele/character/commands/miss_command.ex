defmodule Kantele.Character.MissCommand do
  @moduledoc """
  追寻命令：`miss`

  对应 LPC cmds/usr/miss.c
  追寻炼制的物品。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, %{"item" => _item}) do
    conn
    |> render(CommandView, "text", %{text: "追寻系统暂未开放。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  def run(conn, %{}) do
    conn
    |> render(CommandView, "text", %{text: "你要追寻什么物品？\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
