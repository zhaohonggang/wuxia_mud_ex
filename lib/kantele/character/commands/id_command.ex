defmodule Kantele.Character.IdCommand do
  @moduledoc """
  物品ID命令：`id`

  对应 LPC cmds/usr/id.c
  查看物品ID。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, _params) do
    conn
    |> render(CommandView, "text", %{text: "请使用 i 或 inventory 查看物品。\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
