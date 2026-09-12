defmodule Kantele.Character.DetailView do
  @moduledoc """
  综合状态命令 `detail [玩家]` 的展示：合并 score / info / 背包（i）三块输出
  """

  use Kalevala.Character.View

  alias Kalevala.Character.Conn.EventText
  alias Kantele.Character.InfoView
  alias Kantele.Character.InventoryView
  alias Kantele.Character.ScoreView

  def render("display", assigns) do
    %EventText{
      topic: "Character.Detail",
      data: %{name: assigns.name, self: assigns.self?},
      text: render("_display", assigns)
    }
  end

  def render("_display", assigns) do
    header =
      case assigns.self? do
        true -> ""
        false -> "╔══════════ 目标：#{assigns.name} ══════════╗\n"
      end

    items =
      case assigns.items do
        [] ->
          ""

        _ ->
          "╠══════════ 携带物品 ══════════╣\n" <>
            IO.iodata_to_binary(
              InventoryView.render("_items", %{item_instances: assigns.items})
            )
      end

    IO.iodata_to_binary([
      header,
      ScoreView.render("_display", assigns.score),
      "\n",
      InfoView.render("_display", assigns.info),
      items
    ])
  end
end