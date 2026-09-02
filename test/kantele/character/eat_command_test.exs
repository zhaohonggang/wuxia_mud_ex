defmodule Kantele.Character.EatCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kalevala.Verb
  alias Kantele.Character.EatCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.Items
  alias Kalevala.World.Item

  @food_id "test:baozi"
  @inedible_id "test:rock"

  setup_all do
    Items.put(@food_id, %Item{
      id: @food_id,
      name: "肉包子",
      verbs: [%Verb{key: :eat, conditions: %Verb.Conditions{location: ["inventory/self"]}}],
      callback_module: Kantele.World.Item,
      meta: %{food: 50}
    })

    Items.put(@inedible_id, %Item{
      id: @inedible_id,
      name: "石头",
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

  defp player_with_food(qi \\ 4900) do
    vitals = %Vitals{
      jing: 2000,
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

    food_instance = %Kalevala.World.Item.Instance{
      id: "包子",
      item_id: @food_id,
      created_at: DateTime.utc_now()
    }

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: [food_instance],
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: combat
      }
    }
  end

  defp player_with_capped_stats do
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
      str: 30,
      dex: 30,
      con: 30,
      int: 30,
      skills: %{},
      mapped: %{},
      performs: MapSet.new(),
      combat_exp: 1000,
      score: 0,
      potential: 100,
      weiwang: 0
    }

    combat = Kantele.Character.Combat.new()

    med_instance = %Kalevala.World.Item.Instance{
      id: "test:medicine",
      item_id: "test:medicine",
      created_at: DateTime.utc_now()
    }

    Items.put("test:medicine", %Item{
      id: "test:medicine",
      name: "大还丹",
      verbs: [%Verb{key: :eat, conditions: %Verb.Conditions{location: ["inventory/self"]}}],
      callback_module: Kantele.World.Item,
      meta: %{medicine: %{str: 1, dex: 1, con: 1, int: 1}}
    })

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: [med_instance],
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: combat
      }
    }
  end

  defp player_with_inedible do
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

    rock_instance = %Kalevala.World.Item.Instance{
      id: @inedible_id,
      item_id: @inedible_id,
      created_at: DateTime.utc_now()
    }

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: [rock_instance],
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

  describe "eat 命令" do
    test "身上没有食物报错" do
      p = player()
      conn = EatCommand.run(build_conn(p), %{"item_name" => "包子"})
      text = output_text(conn)

      assert text =~ "你身上没有这样东西"
    end

    test "eat 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("eat 包子")
      assert parsed.module == EatCommand
    end

    test "吃 别名路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("吃 包子")
      assert parsed.module == EatCommand
    end

    test "吃食物成功，饱食度恢复" do
      p = player_with_food(4900)
      conn = EatCommand.run(build_conn(p), %{"item_name" => "包子"})
      text = output_text(conn)

      assert text =~ "吃下"
      assert text =~ "肉包子"
      assert text =~ "气血"
      updated = conn.private.update_character || conn.character
      assert updated.inventory == []
    end

    test "不可食用的物品报错" do
      p = player_with_inedible()
      conn = EatCommand.run(build_conn(p), %{"item_name" => "石头"})
      text = output_text(conn)

      assert text =~ "可不能这么往嘴里塞"
    end
  end
end