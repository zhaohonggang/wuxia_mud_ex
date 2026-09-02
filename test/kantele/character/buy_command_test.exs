defmodule Kantele.Character.BuyCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.BuyCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  defp player() do
    vitals = %Vitals{
      jing: 2000,
      jingli: 2000,
      neili: 9000,
      max_neili: 10000,
      max_jingli: 2000,
      qi: 5000,
      max_qi: 5000
    }

    stats = %Stats{
      str: 20,
      dex: 20,
      con: 20,
      int: 20,
      skills: %{},
      mapped: %{},
      performs: MapSet.new(),
      combat_exp: 1000,
      score: 0,
      potential: 100,
      weiwang: 0
    }

    combat = Kantele.Character.Combat.new()

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: [],
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: combat
      }
    }
  end

  defp shop_events(conn) do
    Enum.filter(conn.events, fn event -> event.topic == "shop/buy" end)
  end

  describe "buy 命令" do
    test "购买单个发出 shop/buy 事件" do
      p = player()
      conn = BuyCommand.run(build_conn(p), %{"item_name" => "铁剑"})
      event = hd(shop_events(conn))

      assert event.data.item_name == "铁剑"
      assert event.data.quantity == 1
    end

    test "带 xN 数量解析" do
      p = player()
      conn = BuyCommand.run(build_conn(p), %{"item_name" => "金疮药 x5"})
      event = hd(shop_events(conn))

      assert event.data.item_name == "金疮药"
      assert event.data.quantity == 5
    end

    test "buy 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("buy 铁剑")
      assert parsed.module == BuyCommand
    end

    test "买 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("买 铁剑")
      assert parsed.module == BuyCommand
    end
  end
end