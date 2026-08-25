defmodule Kantele.Character.ShopTest do
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kalevala.Event
  alias Kalevala.World.Item
  alias Kantele.Character.AskCommand
  alias Kantele.Character.BuyCommand
  alias Kantele.Character.NpcShopEvent
  alias Kantele.Character.NonPlayerMeta
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.ShopEvent
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.Item.Meta
  alias Kantele.World.Items

  setup do
    Items.put("liuxi:baozi", %Item{
      id: "liuxi:baozi",
      name: "包子 Baozi",
      verbs: [],
      callback_module: Kantele.World.Item,
      meta: %Meta{value: 15, food: 20}
    })

    :ok
  end

  defp vendor() do
    %Kalevala.Character{
      id: "liuxi:xiaoer",
      name: "店小二",
      pid: self(),
      room_id: "test:room",
      meta: %NonPlayerMeta{goods: ["liuxi:baozi"], inquiries: nil}
    }
  end

  defp buyer(coins \\ 100) do
    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: [],
      meta: %PlayerMeta{
        vitals: Vitals.new(),
        stats: Stats.new(),
        combat: Kantele.Character.Combat.new(),
        coins: coins
      }
    }
  end

  test "NPC 应答货单（shop/list-result 回给玩家进程）" do
    conn = NpcShopEvent.list(build_conn(vendor()), list_event())

    assert conn != nil

    assert_receive %Event{topic: "shop/list-result", data: data}
    assert data.vendor == "店小二"
    assert [%{item_id: "liuxi:baozi", name: "包子 Baozi", price: 15}] = data.items
  end

  test "非商人（无 goods）不应答" do
    no_goods = %{vendor() | meta: %NonPlayerMeta{goods: nil}}

    NpcShopEvent.list(build_conn(no_goods), list_event())

    refute_receive %Event{}, 100
  end

  test "NPC 对在售物品报价" do
    NpcShopEvent.buy(build_conn(vendor()), buy_event("包子"))

    assert_receive %Event{topic: "shop/buy-result", data: data}
    assert data.unavailable == false
    assert data.price == 15
    assert data.item_name == "包子 Baozi"
  end

  test "NPC 对不在售物品回复 unavailable" do
    NpcShopEvent.buy(build_conn(vendor()), buy_event("长剑"))

    assert_receive %Event{topic: "shop/buy-result", data: data}
    assert data.unavailable == true
  end

  test "玩家成交：扣钱入包并落盘路径不抛" do
    quote_data = %{
      vendor: "店小二",
      unavailable: false,
      item_id: "liuxi:baozi",
      item_name: "包子 Baozi",
      price: 15,
      buyer_id: "player-1"
    }

    conn =
      ShopEvent.buy_result(build_conn(buyer(100)), %Event{
        topic: "shop/buy-result",
        data: quote_data
      })

    updated = conn.private.update_character || conn.character

    assert updated.meta.coins == 85
    assert [%Kalevala.World.Item.Instance{item_id: "liuxi:baozi"}] = updated.inventory
    assert output_text(conn) =~ "买下"
  end

  test "钱不够被拒" do
    quote_data = %{
      vendor: "店小二",
      unavailable: false,
      item_id: "liuxi:baozi",
      item_name: "包子 Baozi",
      price: 15,
      buyer_id: "player-1"
    }

    conn = ShopEvent.buy_result(build_conn(buyer(10)), %Event{topic: "shop/buy-result", data: quote_data})

    updated = conn.private.update_character || conn.character
    assert updated.meta.coins == 10
    assert updated.inventory == []
    assert output_text(conn) =~ "钱不够"
  end

  test "别人的报价事件不处理" do
    quote_data = %{
      vendor: "店小二",
      unavailable: false,
      item_id: "liuxi:baozi",
      item_name: "包子 Baozi",
      price: 15,
      buyer_id: "someone-else"
    }

    conn = ShopEvent.buy_result(build_conn(buyer()), %Event{topic: "shop/buy-result", data: quote_data})

    assert conn.private.update_character == nil
  end

  test "ask 命令剥离 about/关于 前缀" do
    character = buyer()
    conn = AskCommand.run(build_conn(character), %{"name" => "店小二", "keyword" => "about 柳溪"})
    assert [%Event{topic: "characters/ask", data: %{keyword: "柳溪"}}] = conn.events

    conn = AskCommand.run(build_conn(character), %{"name" => "店小二", "keyword" => "关于 黑虎"})
    assert [%Event{data: %{keyword: "黑虎"}}] = conn.events
  end

  test "buy/ask 路由解析" do
    {:ok, parsed} = Kantele.Character.Commands.parse("buy 包子")
    assert parsed.function == :run

    {:ok, parsed} = Kantele.Character.Commands.parse("问 店小二 柳溪")
    assert parsed.function == :run
  end

  defp list_event(),
    do: %Event{topic: "shop/list", data: %{reply_to: self()}}

  defp buy_event(item_name),
    do: %Event{
      topic: "shop/buy",
      data: %{reply_to: self(), item_name: item_name, buyer_id: "player-1", buyer_name: "张三"}
    }

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end
end
