defmodule Kantele.World.ForgingQiankunTest do
  @moduledoc """
  S4 边界分支：乾坤袋（LPC moye.c `qiankun stone`）。

  - `show 乾坤石` → 两段说明（do_show L213-220），不是估价
  - `give 乾坤石`（无背包）→ 报价 value/60 = 500 两黄金，进 item_gived
  - `give 乾坤石`（已有背包 <100）→ 免费 +5 格，不建会话
  - `give 乾坤石`（背包 ≥100）→ 「已经强化到极限了」
  - 付足钱 → 得如意乾坤袋，石头销毁，会话清
  """
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kalevala.Character
  alias Kalevala.World.Item
  alias Kalevala.World.Item.Instance
  alias Kantele.Character.GiveEvent
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.ShowCommand
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.Forging
  alias Kantele.World.ForgingAccept
  alias Kantele.World.Item.Meta
  alias Kantele.World.Items

  @from_id "player-qiankun"
  @from_name "李四"
  @stone "signature:qiankun_stone"
  @bag "signature:qiankun_bag"
  @gold "forge:gold_qiankun"

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(ExVenture.Repo)

    Forging.ensure_table()
    Forging.delete(@from_id)

    Items.put(@stone, %Item{
      id: @stone,
      name: "乾坤石 Qiankun Stone",
      verbs: [],
      callback_module: Kantele.World.Item,
      meta: %Meta{value: 30_000, weight: 100}
    })

    Items.put(@bag, %Item{
      id: @bag,
      name: "如意乾坤袋 Ruyi Qiankun Bag",
      verbs: [],
      callback_module: Kantele.World.Item,
      meta: %Meta{value: 1000, storage_bag: 1}
    })

    # 5,000,000 文 = 500 两黄金（1 金 = 10000 文）
    Items.put(@gold, %Item{
      id: @gold,
      name: "黄金 Gold",
      verbs: [],
      callback_module: Kantele.World.Item,
      meta: %{"is_money" => true, "amount" => 5_000_000}
    })

    on_exit(fn ->
      Forging.delete(@from_id)
      Items.delete(@stone)
      Items.delete(@bag)
      Items.delete(@gold)
    end)

    :ok
  end

  defp moye do
    %Character{
      id: "moye-1",
      name: "莫邪 Moye",
      pid: self(),
      room_id: "test:room",
      inventory: [],
      attributes: %{},
      meta: %{accept: [%{kind: "forge"}]}
    }
  end

  defp player(inventory) do
    vitals = struct(Vitals.new())
    stats = struct(Stats.new(), skills: %{})

    %Character{
      id: @from_id,
      name: @from_name,
      pid: self(),
      room_id: "test:room",
      inventory: inventory,
      attributes: %{},
      meta: %PlayerMeta{vitals: vitals, stats: stats, combat: %{equipped: %{}}}
    }
  end

  defp inst(item_id, id \\ nil) do
    %Instance{id: id || "instance-#{item_id}", item_id: item_id, created_at: DateTime.utc_now()}
  end

  defp data_for(item_instance, extra \\ %{}) do
    Map.merge(
      %{from_id: @from_id, from_name: @from_name, reply_to: self(), item_instance: item_instance},
      extra
    )
  end

  defp conn_output(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  defp updated_char(conn), do: conn.private.update_character || conn.character

  describe "show 乾坤石" do
    test "给两段说明（可炼制 500 两黄金 / 可免费升级 +5 格），不是估价" do
      conn = build_conn(player([inst(@stone)]))
      conn2 = ShowCommand.run(conn, %{"rest" => "乾坤石"})
      text = conn_output(conn2)

      assert text =~ "这是炼制背包(如意乾坤袋)的材料"
      assert text =~ "只要五百两黄金"
      assert text =~ "每次升级可增加五格空间"
      refute text =~ "要是没有问题，请给我原料并付钱"
    end
  end

  describe "给乾坤石（accept_object）" do
    test "无背包 → 报价 500 两黄金，记 item_gived + qiankun，石头收进莫邪背包" do
      conn = build_conn(moye())
      item = inst(@stone)

      conn2 =
        ForgingAccept.handle(conn, conn.character, item, data_for(item, %{bag_extra: 0}), @from_name)

      session = Forging.get(@from_id)
      assert session.status == "item_gived"
      assert session.qiankun == true
      assert session.value == 5_000_000
      assert session.material_item_id == @stone

      assert Enum.any?(updated_char(conn2).inventory, &(&1.id == item.id))

      assert_receive %Kalevala.Event{topic: "forge/accept", data: %{ok: true, message: msg}}
      assert msg =~ "炼制如意乾坤袋需要五百两黄金"
    end

    test "已有背包（6 格）→ 免费 +5，不建会话，回执带 upgrade_bag" do
      conn = build_conn(moye())
      item = inst(@stone)

      conn2 =
        ForgingAccept.handle(conn, conn.character, item, data_for(item, %{bag_extra: 6}), @from_name)

      assert Forging.get(@from_id) == nil
      assert Enum.any?(updated_char(conn2).inventory, &(&1.id == item.id))

      assert_receive %Kalevala.Event{
        topic: "forge/accept",
        data: %{ok: true, upgrade_bag: 5}
      }
    end

    test "背包已达 100 格 → 拒绝，石头留在玩家手里" do
      conn = build_conn(moye())
      item = inst(@stone)

      conn2 =
        ForgingAccept.handle(conn, conn.character, item, data_for(item, %{bag_extra: 100}), @from_name)

      assert Forging.get(@from_id) == nil
      refute Enum.any?(updated_char(conn2).inventory, &(&1.id == item.id))

      assert_receive %Kalevala.Event{topic: "forge/accept", data: %{ok: false, message: msg}}
      assert msg =~ "已经强化到极限"
    end
  end

  describe "付钱炼成" do
    test "付足 500 两黄金 → 得如意乾坤袋 + 石头销毁 + 会话清" do
      Forging.put(@from_id, %{
        status: "item_gived",
        value: 5_000_000,
        material_item_id: @stone,
        material_instance_id: "inst-stone",
        owner_id: @from_id,
        owner_name: @from_name,
        types: nil,
        qiankun: true
      })

      moye_char = %{moye() | inventory: [inst(@stone, "inst-stone")]}
      conn = build_conn(moye_char)
      gold = inst(@gold)

      conn2 = ForgingAccept.handle(conn, conn.character, gold, data_for(gold), @from_name)

      assert Forging.get(@from_id) == nil

      assert_receive %Kalevala.Event{
        topic: "forge/accept",
        data: %{ok: true, grant_item_id: @bag, message: msg}
      }

      assert msg =~ "如意乾坤袋"

      # 石头从莫邪背包销毁
      refute Enum.any?(updated_char(conn2).inventory, &(&1.id == "inst-stone"))
    end
  end

  describe "玩家侧结算（forge_accept）" do
    test "grant_item_id → 背包多一件如意乾坤袋" do
      conn = build_conn(player([]))

      conn2 =
        GiveEvent.forge_accept(conn, %{
          data: %{ok: true, instance_id: "nothing", message: "炼成了\n", grant_item_id: @bag}
        })

      assert Enum.any?(updated_char(conn2).inventory, &(&1.item_id == @bag))
    end

    test "upgrade_bag → 只改该实例 meta（定义 1 + 5 = 6），全局定义不变" do
      bag_inst = %Instance{id: "bag-inst", item_id: @bag, created_at: DateTime.utc_now(), meta: %{}}
      conn = build_conn(player([bag_inst]))

      conn2 =
        GiveEvent.forge_accept(conn, %{
          data: %{ok: true, instance_id: "nothing", message: "", upgrade_bag: 5}
        })

      updated = Enum.find(updated_char(conn2).inventory, &(&1.id == "bag-inst"))
      assert updated.meta["storage_bag"] == 6

      # 全局物品定义不能被改（否则一个玩家的升级摊到所有人）
      assert Items.get!(@bag).meta.storage_bag == 1
      # 扩展格统计也走实例 meta
      assert Forging.bag_extra(updated_char(conn2)) == 6
    end
  end
end
