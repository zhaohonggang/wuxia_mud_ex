defmodule Kantele.Character.FillCommandTest.FakeRoom do
  @moduledoc """
  只满足 `Kantele.World.Room.snapshot/1` 的最小房间：`state.data` 是
  `%Kantele.World.Room{}`（带 flags），`state.private` 提供 characters/item_instances。
  """

  use GenServer

  def start_link({room_id, flags}) do
    GenServer.start_link(__MODULE__, {room_id, flags},
      name: {:global, {Kalevala.World.Room, room_id}}
    )
  end

  @impl true
  def init({room_id, flags}) do
    {:ok,
     %{
       data: %Kantele.World.Room{id: room_id, flags: flags},
       private: %{characters: [], item_instances: []}
     }}
  end
end

defmodule Kantele.Character.FillCommandTest do
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kalevala.World.Item
  alias Kantele.Character.FillCommand
  alias Kantele.Character.FillCommandTest.FakeRoom
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.Items

  @spring "test:spring"
  @dry "test:dry"
  @container_id "test:jiudai"
  @stone_id "test:stone"

  setup_all do
    {:ok, pid} = FakeRoom.start_link({@spring, ["water"]})

    Items.put(@container_id, %Item{
      id: @container_id,
      name: "酒袋",
      verbs: [],
      callback_module: Kantele.World.Item,
      meta: %Kantele.World.Item.Meta{
        max_liquid: 15,
        liquid: %{type: "alcohol", name: "米酒", remaining: 5}
      }
    })

    Items.put(@stone_id, %Item{
      id: @stone_id,
      name: "石头",
      verbs: [],
      callback_module: Kantele.World.Item,
      meta: %Kantele.World.Item.Meta{}
    })

    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)

    :ok
  end

  defp player(room_id, opts \\ []) do
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
      combat_exp: 0,
      score: 0,
      potential: 0,
      weiwang: 0
    }

    combat = Kantele.Character.Combat.new()
    temp = Keyword.get(opts, :temp, %{})

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: room_id,
      inventory: Keyword.get(opts, :inventory, []),
      meta: %PlayerMeta{vitals: vitals, stats: stats, combat: combat, temp: temp}
    }
  end

  defp instance(item_id, id, meta \\ %{}) do
    %Kalevala.World.Item.Instance{
      id: id,
      item_id: item_id,
      created_at: DateTime.utc_now(),
      meta: meta
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

  describe "fill 命令（LPC cmds/std/fill.c 顺序）" do
    test "房间里没有水源：先报「这里没有地方可以装水」" do
      p = player(@dry, inventory: [instance(@container_id, "bag-1")])
      conn = FillCommand.run(build_conn(p), %{"item_name" => "酒袋"})

      assert output_text(conn) =~ "这里没有地方可以装水"
    end

    test "有水源但身上没有该物品" do
      p = player(@spring)
      conn = FillCommand.run(build_conn(p), %{"item_name" => "酒袋"})

      assert output_text(conn) =~ "你身上没有这样东西"
    end

    test "有水源但物品不是容器" do
      p = player(@spring, inventory: [instance(@stone_id, "stone-1")])
      conn = FillCommand.run(build_conn(p), %{"item_name" => "石头"})

      assert output_text(conn) =~ "这个容器装不了水"
    end

    test "容器里有米酒：灌满清水并覆盖实例状态" do
      p = player(@spring, inventory: [instance(@container_id, "bag-2")])
      conn = FillCommand.run(build_conn(p), %{"item_name" => "酒袋"})

      updated = conn.private.update_character || conn.character
      [inst] = updated.inventory
      assert inst.meta["liquid_name"] == "清水"
      assert inst.meta["liquid_type"] == "water"
      # LPC: remaining = max_liquid
      assert inst.meta["liquid_remaining"] == 15
    end

    test "已空容器：同样灌满到 max_liquid" do
      p =
        player(@spring,
          inventory: [instance(@container_id, "bag-3", %{"liquid_remaining" => 0})]
        )

      conn = FillCommand.run(build_conn(p), %{"item_name" => "酒袋"})

      updated = conn.private.update_character || conn.character
      assert hd(updated.inventory).meta["liquid_remaining"] == 15
    end

    test "忙：不灌水" do
      p =
        player(@spring,
          inventory: [instance(@container_id, "bag-4")],
          temp: %{"busy" => 1}
        )

      conn = FillCommand.run(build_conn(p), %{"item_name" => "酒袋"})

      assert output_text(conn) =~ "你上一个动作还没有完成"
      updated = conn.private.update_character || conn.character
      assert hd(updated.inventory).meta["liquid_remaining"] == nil
    end

    test "战斗中：不灌水" do
      combat = %{Kantele.Character.Combat.new() | enemies: [%{id: "npc-1"}]}
      p = player(@spring, inventory: [instance(@container_id, "bag-5")])
      p = %{p | meta: %{p.meta | combat: combat}}

      conn = FillCommand.run(build_conn(p), %{"item_name" => "酒袋"})

      assert output_text(conn) =~ "你正忙着打架，没工夫装水"
    end

    test "路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("fill 水袋")
      assert parsed.module == FillCommand
    end

    test "灌水 别名路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("灌水 水袋")
      assert parsed.module == FillCommand
    end
  end
end
