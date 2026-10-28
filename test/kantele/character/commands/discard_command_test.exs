defmodule Kantele.Character.DiscardCommandTest do
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kalevala.Character
  alias Kalevala.Character.Conn
  alias Kalevala.World.Item, as: ItemDef
  alias Kalevala.World.Item.Instance
  alias Kantele.World.Items
  alias Kantele.World.Item
  alias Kantele.World.Item.Meta
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Character.DiscardCommand

  @owner_id "player-discard-1"
  @owner_name "孙七"

  setup do
    # 自制武器定义（item_make=true, owner_id=玩家，value=100000 文 = 100 金）
    Items.put("forge:#{@owner_id}-xuantiejian", %ItemDef{
      id: "forge:#{@owner_id}-xuantiejian",
      name: "玄铁剑",
      verbs: [],
      callback_module: Item,
      meta: %Meta{
        item_make: true,
        owner: @owner_name,
        owner_id: @owner_id,
        value: 100_000
      }
    })

    on_exit fn ->
      Items.delete("forge:#{@owner_id}-xuantiejian")
    end

    :ok
  end

  defp player(coins \\ 0) do
    vitals = struct(Vitals.new())
    stats = struct(Stats.new())

    %Character{
      id: @owner_id,
      name: @owner_name,
      pid: self(),
      room_id: "test:room",
      inventory: [],
      attributes: %{},
      meta: %PlayerMeta{vitals: vitals, stats: stats, coins: coins}
    }
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  defp updated_char(conn), do: conn.private.update_character || conn.character

  defp forged_instance() do
    %Instance{
      id: "inst-xuantiejian",
      item_id: "forge:#{@owner_id}-xuantiejian",
      created_at: DateTime.utc_now()
    }
  end

  describe "路由解析" do
    test "discard 落在 DiscardCommand" do
      {:ok, parsed} = Kantele.Character.Commands.parse("discard 玄铁剑")
      assert parsed.module == DiscardCommand
    end
  end

  describe "退款" do
    test "自制物品且本人：移除物品、退款 80%（向上取整到整两）" do
      # value = 100000 文 = 100 金；80% = 80000 文 = 8 金
      character =
        player(0)
        |> Map.put(:inventory, [forged_instance()])

      conn = DiscardCommand.run(build_conn(character), %{"item_name" => "玄铁剑"})

      c = updated_char(conn)

      # 物品移除
      refute Enum.any?(c.inventory, &(&1.item_id == "forge:#{@owner_id}-xuantiejian"))

      # 退款入账：80000 文
      assert c.meta.coins == 80_000

      # 输出文案
      assert output_text(conn) =~ "交回干将"
      assert output_text(conn) =~ "退还8两黄金"
    end

    test "非自制物品 → 拒绝，物品不移除" do
      Items.put("forge:common-sword", %ItemDef{
        id: "forge:common-sword",
        name: "普通长剑",
        verbs: [],
        callback_module: Item,
        meta: %Meta{value: 1000}
      })

      character =
        player(0)
        |> Map.put(:inventory, [%Instance{
          id: "inst-common",
          item_id: "forge:common-sword",
          created_at: DateTime.utc_now()
        }])

      conn = DiscardCommand.run(build_conn(character), %{"item_name" => "普通长剑"})

      assert output_text(conn) =~ "不是自制物品"

      c = updated_char(conn)
      assert length(c.inventory) == 1

      Items.delete("forge:common-sword")
    end

    test "他人锻造的自制物品 → 拒绝" do
      Items.put("forge:#{@owner_id}-otherjian", %ItemDef{
        id: "forge:#{@owner_id}-otherjian",
        name: "他人玄铁剑",
        verbs: [],
        callback_module: Item,
        meta: %Meta{item_make: true, owner: "他人", owner_id: "other-player", value: 100_000}
      })

      character =
        player(0)
        |> Map.put(:inventory, [%Instance{
          id: "inst-other",
          item_id: "forge:#{@owner_id}-otherjian",
          created_at: DateTime.utc_now()
        }])

      conn = DiscardCommand.run(build_conn(character), %{"item_name" => "他人玄铁剑"})

      assert output_text(conn) =~ "不是你锻造的"

      c = updated_char(conn)
      assert length(c.inventory) == 1

      Items.delete("forge:#{@owner_id}-otherjian")
    end

    test "背包里没有该物品 → 提示，不扣钱" do
      conn = DiscardCommand.run(build_conn(player(500)), %{"item_name" => "玄铁剑"})

      assert output_text(conn) =~ "你身上没有"
      assert updated_char(conn).meta.coins == 500
    end

    test "裸 discard（无参数） → 提示" do
      conn = DiscardCommand.run(build_conn(player(0)), %{})

      assert output_text(conn) =~ "你想退回什么"
    end
  end
end
