defmodule Kantele.World.ForgingAcceptTest do
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kalevala.Character
  alias Kalevala.World.Item
  alias Kalevala.World.Item.Instance
  alias Kantele.Character.GiveEvent
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.Forging
  alias Kantele.World.ForgingAccept
  alias Kantele.World.Item.Meta
  alias Kantele.World.Items

  @from_id "player-1"
  @from_name "张三"

  setup do
    Forging.delete(@from_id)

    # 锻造材料：material_attrib + power_point + can_make="all"
    # 报价 = 100*2+20 = 220 两黄金；内部记账 = 220 * 10000 = 2_200_000 文
    Items.put("forge:xuantie", %Item{
      id: "forge:xuantie",
      name: "玄铁 Xuantie",
      verbs: [],
      callback_module: Kantele.World.Item,
      meta: %Meta{material_attrib: "steel", material_name: "玄铁", power_point: 100, can_make: "all"}
    })

    # 钱币（足够）：220 两黄金 = 2_200_000 文（meta.amount 单位是文）
    Items.put("forge:gold", %Item{
      id: "forge:gold",
      name: "黄金 Gold",
      verbs: [],
      callback_module: Kantele.World.Item,
      meta: %{"is_money" => true, "amount" => 2_200_000}
    })

    # 钱币（不足）：1_000_000 文 < 2_200_000 文
    Items.put("forge:gold_low", %Item{
      id: "forge:gold_low",
      name: "碎银 Silver",
      verbs: [],
      callback_module: Kantele.World.Item,
      meta: %{"is_money" => true, "amount" => 1_000_000}
    })

    # 普通物品：无 material_attrib、非钱币
    Items.put("forge:plain", %Item{
      id: "forge:plain",
      name: "废铁 Feitie",
      verbs: [],
      callback_module: Kantele.World.Item,
      meta: %Meta{}
    })

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
      meta: %PlayerMeta{vitals: vitals, stats: stats}
    }
  end

  defp inst(item_id, id \\ nil) do
    %Instance{id: id || "instance-#{item_id}", item_id: item_id, created_at: DateTime.utc_now()}
  end

  defp data_for(item_instance) do
    %{from_id: @from_id, from_name: @from_name, reply_to: self(), item_instance: item_instance}
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

  describe "给材料（material）" do
    test "估价 + 记 item_gived + 收进莫邪背包 + 送达玩家" do
      conn = build_conn(moye())
      item = inst("forge:xuantie")

      conn2 = ForgingAccept.handle(conn, conn.character, item, data_for(item), @from_name)

      # 会话：item_gived + value=220 两 * 10000 = 2_200_000 文
      assert %{status: "item_gived", value: 2_200_000, material_item_id: "forge:xuantie"} =
               Forging.get(@from_id)

      # 莫邪背包收到材料
      assert Enum.any?(updated_char(conn2).inventory, fn i -> i.id == item.id end)

      # 玩家侧收到 forge/accept ok，文案正确（对外仍按「两黄金」报价）
      assert_receive %Kalevala.Event{topic: "forge/accept", data: %{ok: true, message: msg}}
      assert msg =~ "莫邪对你说道：很好，用这块原料打造道具需要二百二十两黄金。"
      refute msg =~ "原来是巫师啊"
    end

    test "巫师 → 只收 1 文，并额外一句巫师提示" do
      conn = build_conn(moye())
      item = inst("forge:xuantie")

      data = Map.put(data_for(item), :wizard, true)
      ForgingAccept.handle(conn, conn.character, item, data, @from_name)

      assert %{status: "item_gived", value: 1} = Forging.get(@from_id)

      assert_receive %Kalevala.Event{topic: "forge/accept", data: %{ok: true, message: msg}}
      assert msg =~ "需要二百二十两黄金。"
      assert msg =~ "原来是巫师啊，那么你随便给点好了。"
    end
  end

  describe "给钱币（money）" do
    setup do
      Forging.put(@from_id, %{
        status: "item_gived",
        value: 2_200_000,
        material_item_id: "forge:xuantie",
        material_instance_id: "instance-forge:xuantie",
        owner_id: @from_id,
        owner_name: @from_name,
        types: nil
      })

      :ok
    end

    test "金额足够 → 枚举类型 + answer_type" do
      conn = build_conn(moye())
      item = inst("forge:gold")

      ForgingAccept.handle(conn, conn.character, item, data_for(item), @from_name)

      sess = Forging.get(@from_id)
      assert sess.status == "answer_type"
      # can_make="all" → 全部 17 种类型
      assert "剑" in sess.types and "刀" in sess.types and "指套" in sess.types
      assert length(sess.types) == 17

      assert_receive %Kalevala.Event{topic: "forge/accept", data: %{ok: true, message: msg}}
      assert msg =~ "好，这就给你炼。你打算锻造什么东西，请告诉(answer <类型>)我类型。"
      assert msg =~ "刀" and msg =~ "剑"
    end

    test "金额不足 → 拒绝「没有打过折扣」，会话不变" do
      conn = build_conn(moye())
      item = inst("forge:gold_low")

      ForgingAccept.handle(conn, conn.character, item, data_for(item), @from_name)

      assert %{status: "item_gived"} = Forging.get(@from_id)
      assert_receive %Kalevala.Event{topic: "forge/accept", data: %{ok: false, message: msg}}
      assert msg =~ "本店开张千多年来，还没有打过折扣。"
    end
  end

  describe "异常分支" do
    test "未交材料先给钱 → 拒绝「无功不受禄」" do
      conn = build_conn(moye())
      item = inst("forge:gold")

      ForgingAccept.handle(conn, conn.character, item, data_for(item), @from_name)

      assert_receive %Kalevala.Event{topic: "forge/accept", data: %{ok: false, message: msg}}
      assert msg =~ "无功不受禄"
    end

    test "非材料非钱币 → 拒绝「你给我这些东西干什么？」" do
      conn = build_conn(moye())
      item = inst("forge:plain")

      ForgingAccept.handle(conn, conn.character, item, data_for(item), @from_name)

      assert_receive %Kalevala.Event{topic: "forge/accept", data: %{ok: false, message: msg}}
      assert msg =~ "你给我这些东西干什么？"
    end
  end

  describe "玩家侧 forge/accept（物理移除 / 拒收）" do
    test "ok:true → 从背包移除物品并展示莫邪回复" do
      conn = build_conn(player([inst("forge:xuantie")]))

      conn2 =
        GiveEvent.forge_accept(conn, %{
          data: %{ok: true, instance_id: "instance-forge:xuantie", message: "莫邪对你说道：测试回复。\n"}
        })

      refute Enum.any?(updated_char(conn2).inventory, fn i -> i.id == "instance-forge:xuantie" end)
      assert conn_output(conn2) =~ "莫邪对你说道：测试回复。"
    end

    test "ok:false → 物品仍在背包，仅展示拒绝文案" do
      conn = build_conn(player([inst("forge:xuantie")]))

      conn2 =
        GiveEvent.forge_accept(conn, %{
          data: %{ok: false, message: "莫邪把东西推了回来。\n"}
        })

      assert Enum.any?(updated_char(conn2).inventory, fn i -> i.id == "instance-forge:xuantie" end)
      assert conn_output(conn2) =~ "莫邪把东西推了回来。"
    end
  end

  describe "端到端：GiveEvent.receive 命中 forge 规则" do
    test "玩家把材料交给莫邪 → 触发 forge 议价，会话建立" do
      conn = build_conn(moye())
      item = inst("forge:xuantie")

      GiveEvent.receive(conn, %{data: data_for(item)})

      assert %{status: "item_gived", value: 2_200_000} = Forging.get(@from_id)
      assert_receive %Kalevala.Event{topic: "forge/accept", data: %{ok: true}}
    end
  end

  describe "Forging.types_for" do
    test "can_make=all 全量；not_make 剔除" do
      all = Forging.all_types()
      assert length(all) == 17
      assert Forging.types_for("all", nil) == all
      assert Forging.types_for("all", ["剑", "刀"]) == all -- ["剑", "刀"]
    end

    test "can_make 为列表/字符串子集" do
      assert Forging.types_for(["剑", "刀"], nil) == ["剑", "刀"]
      assert Forging.types_for("剑", nil) == ["剑"]
    end
  end
end
