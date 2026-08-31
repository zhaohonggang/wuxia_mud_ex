defmodule Kantele.Character.PurchaseCommand do
  @moduledoc """
  购物命令：`purchase [物品名] [x数量]`

  对应 LPC cmds/std/purchase.c 的简化版（向 NPC 商店购买）。
  复用 shop/buy 事件链路，由房间内的商人报价。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  @max_quantity 100

  def run(conn, params) do
    item_name = String.trim(params["item_name"] || "")

    if item_name == "" do
      conn
      |> render(CommandView, "text", %{text: "你打算购买什么？\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      {item_name, quantity} = parse_quantity(item_name)

      conn
      |> event("shop/buy", %{item_name: item_name, quantity: min(quantity, @max_quantity)})
      |> assign(:prompt, false)
    end
  end

  defp parse_quantity(raw) do
    case Regex.run(~r/^(.+?)\s*x(\d+)$/, raw) do
      [_, name, n] -> {String.trim(name), String.to_integer(n)}
      _ -> {raw, 1}
    end
  end
end
