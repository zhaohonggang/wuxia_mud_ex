defmodule Kantele.Character.ItemCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.ItemCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Character.Combat
  alias Kantele.World.Items
  alias Kalevala.World.Item

  @sword_id "test:sword"
  @armor_id "test:armor"
  @normal_item_id "test:baozi"

  setup_all do
    Items.put(@sword_id, %Item{
      id: @sword_id,
      name: "长剑",
      verbs: [],
      callback_module: Kantele.World.Item,
      meta: %{}
    })

    Items.put(@armor_id, %Item{
      id: @armor_id,
      name: "铁甲",
      verbs: [],
      callback_module: Kantele.World.Item,
      meta: %{}
    })

    Items.put(@normal_item_id, %Item{
      id: @normal_item_id,
      name: "肉包子",
      verbs: [],
      callback_module: Kantele.World.Item,
      meta: %{}
    })

    :ok
  end

  defp player(opts \\ []) do
    vitals = %Vitals{
      jing: Keyword.get(opts, :jing, 2000),
      jingli: Keyword.get(opts, :jingli, 0),
      max_jingli: Keyword.get(opts, :max_jingli, 2000),
      qi: Keyword.get(opts, :qi, 5000),
      max_qi: Keyword.get(opts, :max_qi, 5000),
      neili: Keyword.get(opts, :neili, 9000),
      max_neili: Keyword.get(opts, :max_neili, 10000)
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

    combat = Keyword.get(opts, :combat, Combat.new())

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: Keyword.get(opts, :inventory, []),
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: combat,
        riding: Keyword.get(opts, :riding, nil)
      }
    }
  end

  defp build_item_conn(player, room_opts \\ []) do
    r = %{items: Keyword.get(room_opts, :items, [])}
    build_conn(player) |> Map.put(:room, r)
  end

  describe "drop validation" do
    test "装备中的物品不能丢弃" do
      combat = %{Combat.new() | equipped: %{weapon: %{instance_id: @sword_id}}}
      p = player(inventory: [%Kalevala.World.Item.Instance{id: @sword_id, item_id: @sword_id}], combat: combat)
      conn = build_item_conn(p)

      conn = ItemCommand.drop(conn, %{"item_name" => @sword_id})
      text = conn.output |> Enum.flat_map(fn %Kalevala.Character.Conn.Text{data: d} -> [IO.iodata_to_binary(d)]; _ -> [] end) |> Enum.join("")
      assert text =~ "必须脱下来才能丢掉"
    end

    test "正在骑乘的物品不能丢弃" do
      riding = %Kalevala.World.Item.Instance{id: @sword_id, item_id: @sword_id}
      p = player(inventory: [%Kalevala.World.Item.Instance{id: @sword_id, item_id: @sword_id}], riding: riding)
      conn = build_item_conn(p)

      conn = ItemCommand.drop(conn, %{"item_name" => @sword_id})
      text = conn.output |> Enum.flat_map(fn %Kalevala.Character.Conn.Text{data: d} -> [IO.iodata_to_binary(d)]; _ -> [] end) |> Enum.join("")
      assert text =~ "正在骑乘"
    end

    test "身上没有物品时报错" do
      p = player(inventory: [])
      conn = build_item_conn(p)

      conn = ItemCommand.drop(conn, %{"item_name" => @sword_id})
      text = conn.output |> Enum.flat_map(fn %Kalevala.Character.Conn.Text{data: d} -> [IO.iodata_to_binary(d)]; _ -> [] end) |> Enum.join("")
      assert text =~ "你身上没有这样东西"
    end

    test "可丢弃物品发送drop事件" do
      inst = %Kalevala.World.Item.Instance{id: @normal_item_id, item_id: @normal_item_id}
      p = player(inventory: [inst])
      conn = build_item_conn(p)

      conn = ItemCommand.drop(conn, %{"item_name" => @normal_item_id})
      assert Enum.any?(conn.events, fn e -> e.topic == Kalevala.Event.ItemDrop.Request end)
    end
  end

  describe "get validation" do
    test "附近没有物品时报错" do
      p = player()
      conn = build_item_conn(p, items: [])

      conn = ItemCommand.get(conn, %{"item_name" => @normal_item_id})
      text = conn.output |> Enum.flat_map(fn %Kalevala.Character.Conn.Text{data: d} -> [IO.iodata_to_binary(d)]; _ -> [] end) |> Enum.join("")
      assert text =~ "附近没有"
    end

    test "背包已满时拒绝" do
      inst = %Kalevala.World.Item.Instance{id: @normal_item_id, item_id: @normal_item_id}
      full_inventory = Enum.map(1..80, fn i -> %Kalevala.World.Item.Instance{id: "item-#{i}", item_id: @normal_item_id} end)
      p = player(inventory: full_inventory)
      conn = build_item_conn(p, items: [inst])

      conn = ItemCommand.get(conn, %{"item_name" => @normal_item_id})
      text = conn.output |> Enum.flat_map(fn %Kalevala.Character.Conn.Text{data: d} -> [IO.iodata_to_binary(d)]; _ -> [] end) |> Enum.join("")
      assert text =~ "太多了"
    end

    test "可拾取物品发送pickup事件" do
      inst = %Kalevala.World.Item.Instance{id: @normal_item_id, item_id: @normal_item_id}
      p = player()
      conn = build_item_conn(p, items: [inst])

      conn = ItemCommand.get(conn, %{"item_name" => @normal_item_id})
      assert Enum.any?(conn.events, fn e -> e.topic == Kalevala.Event.ItemPickUp.Request end)
    end
  end
end
