defmodule Kantele.Character.DrinkCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kalevala.Verb
  alias Kantele.Character.DrinkCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.Items
  alias Kalevala.World.Item

  @potion_id "test:potion"
  @nondrinkable_id "test:water"

  setup_all do
    Items.put(@potion_id, %Item{
      id: @potion_id,
      name: "疗伤药水",
      verbs: [%Verb{key: :drink, conditions: %Verb.Conditions{location: ["inventory/self"]}}],
      callback_module: Kantele.World.Item,
      meta: %{medicine: %{qi: 100, jing: 50}}
    })

    Items.put(@nondrinkable_id, %Item{
      id: @nondrinkable_id,
      name: "清水",
      verbs: [],
      callback_module: Kantele.World.Item,
      meta: %{}
    })

    :ok
  end

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

  defp player_with_potion(qi \\ 4900, jing \\ 1900) do
    vitals = %Vitals{
      jing: jing,
      jingli: 2000,
      neili: 9000,
      max_neili: 10000,
      max_jingli: 2000,
      qi: qi,
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

    potion_instance = %Kalevala.World.Item.Instance{
      id: "药水",
      item_id: @potion_id,
      created_at: DateTime.utc_now()
    }

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: [potion_instance],
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: combat
      }
    }
  end

  defp player_with_nondrinkable do
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

    water_instance = %Kalevala.World.Item.Instance{
      id: "清水",
      item_id: @nondrinkable_id,
      created_at: DateTime.utc_now()
    }

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: [water_instance],
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: combat
      }
    }
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  describe "drink 命令" do
    test "身上没有可喝物品报错" do
      p = player()
      conn = DrinkCommand.run(build_conn(p), %{"item_name" => "药水"})
      text = output_text(conn)

      assert text =~ "你身上没有这样东西"
    end

    test "drink 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("drink 药水")
      assert parsed.module == DrinkCommand
    end

    test "heal 别名路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("heal 药水")
      assert parsed.module == DrinkCommand
    end

    test "喝药水成功，气血精力恢复" do
      p = player_with_potion(4900, 1900)
      conn = DrinkCommand.run(build_conn(p), %{"item_name" => "药水"})
      text = output_text(conn)

      assert text =~ "你仰头喝下"
      assert text =~ "疗伤药水"
      updated = conn.private.update_character || conn.character
      assert updated.inventory == []
    end

    test "不可饮用的物品报错" do
      p = player_with_nondrinkable()
      conn = DrinkCommand.run(build_conn(p), %{"item_name" => "清水"})
      text = output_text(conn)

      assert text =~ "可没法往嘴里灌"
    end
  end
end