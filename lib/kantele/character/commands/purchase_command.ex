defmodule Kantele.Character.PurchaseCommand do
  @moduledoc """
  购物命令：`purchase`

  对应 LPC cmds/std/purchase.c
  向NPC购买物品。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, %{"rest" => _rest}) do
    conn
    |> render(CommandView, "text", %{text: "购物系统暂未开放。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  def run(conn, %{}) do
    conn
    |> render(CommandView, "text", %{text: "你打算购买什么？\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
