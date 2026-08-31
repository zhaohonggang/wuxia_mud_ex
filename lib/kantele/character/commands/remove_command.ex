defmodule Kantele.Character.RemoveCommand do
  @moduledoc """
  脱卸命令：`remove`

  对应 LPC cmds/std/remove.c
  脱掉身上装备的防具。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, %{"item" => _item}) do
    conn
    |> render(CommandView, "text", %{text: "脱卸系统暂未开放。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  def run(conn, %{}) do
    conn
    |> render(CommandView, "text", %{text: "你要脱掉什么？\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
