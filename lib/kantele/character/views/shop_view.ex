defmodule Kantele.Character.ShopView do
  @moduledoc """
  商店货单展示（A10/N2）
  """

  use Kalevala.Character.View

  alias Kalevala.Character.Conn.EventText

  def render("list", %{vendor: vendor, items: items}) do
    lines =
      Enum.map(items, fn item ->
        ~i(  {text}#{item.name}{/text}　#{item.price} 文)
      end)

    text = [
      ~i({room-title}#{vendor}{/room-title} 笑呵呵地摊开货物：\n),
      join(lines, "\n"),
      "\n"
    ]

    %EventText{
      topic: "Shop.List",
      data: %{vendor: vendor, items: items},
      text: text
    }
  end

  defp join([], _separator), do: []
  defp join([line], _separator), do: [line]
  defp join([line | lines], separator), do: [line, separator | join(lines, separator)]
end
