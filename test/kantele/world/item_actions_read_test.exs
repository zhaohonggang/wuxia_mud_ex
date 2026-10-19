defmodule Kantele.World.ItemActions.ReadTest do
  @moduledoc """
  书册 `read` 动作单测（第十二批，物品动作通道）。

  泛型实现：命中该书 id 表（UCL `aliases`，对应 LPC `set_name` 的 id 数组）
  → 渲染 `meta.read_text`（只给玩家，不广播）；不命中 → `:not_handled`
  （等价 LPC 穿底 `return 0`）。无 `read_text` 的物品也落空。
  """

  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kalevala.World.Item
  alias Kalevala.World.Item.Instance

  alias Kantele.World.ItemActions.Read
  alias Kantele.World.Room

  @read_text "羽扇纶巾，谈笑间，樯橹灰飞烟灭。"

  defp book(aliases, read_text \\ @read_text) do
    %Item{
      id: "z:shan_book",
      name: "扇上书",
      meta: %{actions: [%{verb: "read", handler: "do_read"}], aliases: aliases, read_text: read_text}
    }
  end

  defp plain_item do
    %Item{id: "z:rock", name: "石头", meta: %{actions: [%{verb: "read", handler: "do_read"}]}}
  end

  defp conn(room_id \\ "z:room") do
    %Conn{
      character: %Kalevala.Character{name: "玩家", room_id: room_id},
      private: %Conn.Private{room: %Room{id: room_id}, channel_changes: []},
      output: []
    }
  end

  defp params(trailing, item, room_id \\ "z:room") do
    %{verb: "read", trailing: trailing, room_id: room_id, item: item, instance: %Instance{item_id: item.id, item: item}, handler: "do_read"}
  end

  defp out_text(conn), do: conn.output |> Enum.map(& &1.data) |> Enum.join()

  describe "命中 id 表 → 渲染 read_text" do
    test "精确别名命中" do
      c = conn()
      c2 = Read.run(c, params("shan_book", book(["shan_book", "book"])))
      assert out_text(c2) == @read_text <> "\n"
    end

    test "第二组别名也命中" do
      c = conn()
      c2 = Read.run(c, params("book", book(["shan_book", "book"])))
      assert String.contains?(out_text(c2), @read_text)
    end

    test "命中物品全名（精确匹配）" do
      c = conn()
      c2 = Read.run(c, params("扇上书", book(["shan_book"])))
      assert String.contains?(out_text(c2), @read_text)
    end
  end

  describe "不命中 → :not_handled（放行全局命令）" do
    test "arg 不是本册 id → return 0" do
      c = conn()
      c2 = Read.run(c, params("xyz", book(["shan_book", "book"])))
      assert c2 == :not_handled
    end

    test "空 arg → 不命中" do
      c = conn()
      c2 = Read.run(c, params("", book(["shan_book"])))
      assert c2 == :not_handled
    end
  end

  describe "无 read_text 的物品自然落空" do
    test "meta 无 read_text → :not_handled" do
      c = conn()
      c2 = Read.run(c, params("rock", plain_item()))
      assert c2 == :not_handled
    end
  end
end
