defmodule Kantele.Character.KaoFireCommandTest do
  @moduledoc """
  `kao`（烤肉）/ `fire`（生火）命令测试：对齐 LPC `clone/misc/needfire.c::do_kao`
  与 `clone/misc/wood.c::fire()`。

  - `kao 生肉`：房间有篝火 → 生肉按 broil_to 变熟食，生肉被消费
  - 房间无篝火 / 背包无生肉 / 非生肉 → 各自拒绝
  - `fire 木柴`：背包有带 fire_to 的木柴 → 房间生成篝火，木柴被消费
  """
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kalevala.Character
  alias Kalevala.Character.Conn
  alias Kalevala.World.Item
  alias Kalevala.World.Item.Instance
  alias Kantele.Character.FireCommand
  alias Kantele.Character.KaoCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Character.Combat
  alias Kantele.World.Items

  @zhurou "clone_lib:zhurou"
  @meat "clone_lib:meat"
  @needfire "clone_lib:needfire"
  @wood "city:shuzhi"

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(ExVenture.Repo)

    Items.put(@zhurou, %Item{
      id: @zhurou,
      name: "野猪肉",
      verbs: [],
      callback_module: Kantele.World.Item,
      meta: %{raw_meat: true, broil_to: @meat, food: 15}
    })

    Items.put(@meat, %Item{
      id: @meat,
      name: "烤肉",
      verbs: [],
      callback_module: Kantele.World.Item,
      meta: %{food: 15}
    })

    Items.put(@needfire, %Item{
      id: @needfire,
      name: "篝火",
      verbs: [],
      callback_module: Kantele.World.Item,
      meta: %{}
    })

    Items.put(@wood, %Item{
      id: @wood,
      name: "大树枝",
      verbs: [],
      callback_module: Kantele.World.Item,
      meta: %{fire_to: @needfire, aliases: ["shu zhi"]}
    })

    :ok
  end

  defp player do
    %Character{
      id: "fire-test-player",
      name: "fire-test-player",
      pid: self(),
      room_id: "village:sexit",
      attributes: %{},
      inventory: [],
      meta: %PlayerMeta{
        vitals: Vitals.new(),
        stats: Stats.new(),
        combat: Combat.new(),
        setup_done: true
      }
    }
  end

  defp instance(id, item_id) do
    %Instance{id: id, item_id: item_id, created_at: DateTime.utc_now()}
  end

  defp conn_with_room(character, item_instances) do
    conn = build_conn(character)
    private = %{conn.private | room: %{private: %{item_instances: item_instances}}}
    %{conn | private: private}
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  # put_character/2 只写 conn.private.update_character（不改 conn.character），读改动必须走这里
  defp updated(conn), do: conn.private.update_character || conn.character

  describe "kao 烤肉" do
    test "房间有篝火 + 背包有生肉 → 烤成烤肉，生肉被消费" do
      meat = instance("m1", @zhurou)
      conn = conn_with_room(%{player() | inventory: [meat]}, [instance("nf1", @needfire)])

      result = KaoCommand.run(conn, %{"item_name" => "野猪肉"})

      text = output_text(result)
      assert String.contains?(text, "烤肉")

      inv_ids = Enum.map(updated(result).inventory, & &1.item_id)
      refute @zhurou in inv_ids
      assert @meat in inv_ids
    end

    test "房间无篝火 → 拒绝" do
      meat = instance("m1", @zhurou)
      conn = conn_with_room(%{player() | inventory: [meat]}, [])

      result = KaoCommand.run(conn, %{"item_name" => "野猪肉"})

      text = output_text(result)
      assert String.contains?(text, "没有篝火")
    end

    test "背包无生肉 → 提示没有这样可烤的东西" do
      conn = conn_with_room(player(), [instance("nf1", @needfire)])

      result = KaoCommand.run(conn, %{"item_name" => "野猪肉"})

      text = output_text(result)
      assert String.contains?(text, "没有这样可烤的东西")
    end

    test "熟食（无 raw_meat）不能烤" do
      cooked = instance("m2", @meat)
      conn = conn_with_room(%{player() | inventory: [cooked]}, [instance("nf1", @needfire)])

      result = KaoCommand.run(conn, %{"item_name" => "烤肉"})

      text = output_text(result)
      assert String.contains?(text, "没有这样可烤的东西")
    end
  end

  describe "fire 生火" do
    test "背包有木柴（fire_to）→ 木柴被消费" do
      wood = instance("w1", @wood)
      conn = conn_with_room(%{player() | inventory: [wood]}, [])

      result = FireCommand.run(conn, %{"item_name" => "大树枝"})

      text = output_text(result)
      assert String.contains?(text, "篝火")

      inv_ids = Enum.map(updated(result).inventory, & &1.item_id)
      refute @wood in inv_ids
    end

    test "背包无木柴 → 提示没有可以点火的东西" do
      conn = conn_with_room(player(), [])

      result = FireCommand.run(conn, %{"item_name" => "大树枝"})

      text = output_text(result)
      assert String.contains?(text, "没有可以点火的东西")
    end

    test "用别名 shu zhi 也能生火（走 item.callback_module.matches?）" do
      wood = instance("w1", @wood)
      conn = conn_with_room(%{player() | inventory: [wood]}, [])

      result = FireCommand.run(conn, %{"item_name" => "shu zhi"})

      text = output_text(result)
      assert String.contains?(text, "篝火")

      inv_ids = Enum.map(updated(result).inventory, & &1.item_id)
      refute @wood in inv_ids
    end
  end
end
