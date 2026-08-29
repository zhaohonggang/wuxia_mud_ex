defmodule Kantele.Character.ShopView do
  @moduledoc """
  商店货单展示（A10/N2）
  """

  use Kalevala.Character.View

  alias Kalevala.Character.Conn.EventText
  alias Kantele.Npc.Vendor

  def render("list", %{vendor: vendor, items: rows}) do
    lines = Enum.map(rows, fn row -> render("_row", %{row: row}) end)

    text = [
      ~i({room-title}#{vendor}{/room-title} 笑呵呵地摊开货物：\n),
      join(lines, "\n"),
      "\n"
    ]

    %EventText{
      topic: "Shop.List",
      data: %{vendor: vendor, items: rows},
      text: text
    }
  end

  # 原版 do_list 样式：名字(id)　(单位) ×数量/大量　：价格串
  def render("_row", %{row: %{short: short, unit: unit, price: price, count: count}}) do
    count_text = if count < 0, do: "大量", else: "#{to_string(count)}"
    pad = String.pad_trailing(short, 28)

    ~i(  {text}#{pad}{/text} {unit}×#{count_text}　：{color foreground="white"}#{Vendor.price_string(price)}{/color}\n)
  end

  defp join([], _separator), do: []
  defp join([line], _separator), do: [line]
  defp join([line | lines], separator), do: [line, separator | join(lines, separator)]
end
