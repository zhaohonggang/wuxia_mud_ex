defmodule Kantele.World.ItemOpenTest do
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kalevala.World.Item.Instance
  alias Kantele.Character.{OpenCommand, PlayerMeta, Stats, Vitals}
  alias Kantele.World.Items

  @jing_id "mingjiao:items.jing"

  setup_all do
    Items.put(@jing_id, %Kalevala.World.Item{
      id: @jing_id,
      name: "「楞伽经」",
      meta: %{aliases: ["lengjia jing", "jing", "book"]}
    })

    :ok
  end

  defp bag_instance(count) do
    item = %Kalevala.World.Item{
      id: "mingjiao:items.bag",
      name: "油布包",
      meta: %{aliases: ["bag", "bao"]}
    }

    %Instance{
      id: "inst-bag",
      item_id: "mingjiao:items.bag",
      created_at: DateTime.utc_now(),
      item: item,
      meta: %{book_count: count}
    }
  end

  defp player(inventory) do
    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: inventory,
      meta: %PlayerMeta{
        vitals: %Vitals{
          jing: 100,
          jingli: 100,
          neili: 100,
          max_neili: 100,
          max_jingli: 100,
          qi: 100,
          max_qi: 100
        },
        stats: %Stats{
          str: 20,
          dex: 20,
          con: 20,
          int: 20,
          combat_exp: 0,
          potential: 0,
          learned_points: 0,
          skills: %{},
          mapped: %{},
          performs: MapSet.new(),
          score: 0,
          weiwang: 0,
          gongxian: 0,
          shen: 0
        },
        combat: Kantele.Character.Combat.new(),
        temp: %{}
      }
    }
  end

  defp current(conn), do: conn.private.update_character || conn.character

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  test "open bag：取出楞伽经，包内计数减一" do
    conn = OpenCommand.run(build_conn(player([bag_instance(1)])), %{"target" => "bag"})
    c = current(conn)

    ids = Enum.map(c.inventory, &Map.get(&1, :item_id))
    assert @jing_id in ids

    bag = Enum.find(c.inventory, &(Map.get(&1, :id) == "inst-bag"))
    assert Map.get(bag.meta, :book_count) == 0
  end

  test "unpack 同义动词也能开包" do
    conn = OpenCommand.run(build_conn(player([bag_instance(1)])), %{"target" => "bao"})
    assert @jing_id in Enum.map(current(conn).inventory, &Map.get(&1, :item_id))
  end

  test "包已空：提示里面什么也没有了，不再发书" do
    conn = OpenCommand.run(build_conn(player([bag_instance(0)])), %{"target" => "bag"})

    assert output_text(conn) =~ "什么也没有了"
    refute @jing_id in Enum.map(current(conn).inventory, &Map.get(&1, :item_id))
  end

  test "目标不是物品：落回房间开门逻辑（提示要打开什么）" do
    conn = OpenCommand.run(build_conn(player([])), %{"target" => "door"})
    assert output_text(conn) =~ "你要打开什么"
  end
end
