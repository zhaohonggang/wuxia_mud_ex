defmodule Kantele.World.MirrorZixuTest do
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kalevala.Event
  alias Kalevala.World.Item
  alias Kantele.Character.GiveCommand
  alias Kantele.Character.MirrorEvent
  alias Kantele.Character.NpcAskEvent
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.Item.Meta
  alias Kantele.World.Items
  alias Kantele.World.Loader
  alias Kantele.World.MirrorDaemon.Zixu

  describe "UCL 里程碑赠礼物品加载" do
    setup do
      %{items: Loader.load().items}
    end

    test "16 个里程碑物品都在世界数据里", %{items: items} do
      for id <- milestone_ids() do
        assert %Item{name: name} = get_item(items, id)
        assert name != ""
      end
    end

    test "乾坤宝镜与仙丹药效字段正确解析", %{items: items} do
      mirror = get_item(items, "liuxi:item/mirror")
      assert mirror.name =~ "乾坤宝镜"
      assert mirror.meta.unit == "面"
      assert mirror.meta.no_sell == 1
      assert mirror.meta.no_put == 1

      str3 = get_item(items, "liuxi:gift/str3")
      assert str3.meta.value == 100_000
      assert str3.meta.unit == "颗"
      assert str3.meta.medicine.stats.str == 1
    end

    test "许愿无花果 no_sell，其余里程碑物品可交易", %{items: items} do
      assert get_item(items, "liuxi:obj/guo").meta.no_sell == 1
      assert get_item(items, "liuxi:gift/kardan").meta.no_sell == nil
      assert get_item(items, "liuxi:max/longjia").meta.no_sell == nil
    end
  end

  describe "子虚道人询问应答（NpcAskEvent）" do
    test "ask 宝镜 → mirror/give 事件回给玩家" do
      conn = NpcAskEvent.call(build_conn(Zixu.build_zixu()), ask_event("宝镜"))

      assert conn != nil

      assert_receive %Event{
        topic: "mirror/give",
        data: %{npc_name: "子虚道人", item_id: "liuxi:item/mirror", asker_id: "player-1"}
      }
    end

    test "ask 乾坤宝镜（含子串 宝镜）同样命中" do
      NpcAskEvent.call(build_conn(Zixu.build_zixu()), ask_event("乾坤宝镜"))

      assert_receive %Event{topic: "mirror/give", data: %{item_id: "liuxi:item/mirror"}}
    end

    test "ask 心魔幻境 → 占位回话，不发镜" do
      conn = NpcAskEvent.call(build_conn(Zixu.build_zixu()), ask_event("心魔幻境"))

      assert conn != nil
      refute_receive %Event{topic: "mirror/give"}, 100
    end

    test "非子虚道人的 atom 问询不处理" do
      zixu = Zixu.build_zixu()
      npc = %{zixu | meta: %{zixu.meta | kind: "other"}}

      conn = NpcAskEvent.call(build_conn(npc), ask_event("宝镜"))

      assert conn != nil
      refute_receive %Event{topic: "mirror/give"}, 100
    end
  end

  describe "玩家侧领镜（MirrorEvent.mirror/give）" do
    setup do
      Items.put("liuxi:item/mirror", %Item{
        id: "liuxi:item/mirror",
        name: "乾坤宝镜 Qiankun Baojing",
        verbs: ["get", "drop"],
        callback_module: Kantele.World.Item,
        meta: %Meta{unit: "面", value: 0, no_sell: 1, no_put: 1}
      })

      :ok
    end

    test "首次领镜入背包" do
      conn = MirrorEvent.give_result(build_conn(player()), give_event())

      updated = conn.private.update_character || conn.character

      assert [%Item.Instance{item_id: "liuxi:item/mirror"}] = updated.inventory

      assert output_text(conn) =~ "递到你手中"
    end

    test "已持有宝镜再领被拒" do
      mirror = %Item.Instance{id: "inst-m", item_id: "liuxi:item/mirror", created_at: DateTime.utc_now()}
      conn = MirrorEvent.give_result(build_conn(player([mirror])), give_event())

      assert conn.private.update_character == nil
      assert output_text(conn) =~ "不是已有一面乾坤宝镜"
    end

    test "mirror_count 已达标（完成过任务）再领被拒" do
      p = player()
      char = %{p | meta: %{p.meta | stats: Map.put(p.meta.stats, :mirror_count, 1)}}

      conn = MirrorEvent.give_result(build_conn(char), give_event())

      assert conn.private.update_character == nil
      assert output_text(conn) =~ "不是已有一面乾坤宝镜"
    end

    test "别人名字的领镜事件不处理" do
      event = %{give_event() | data: %{give_event().data | asker_id: "someone"}}
      conn = MirrorEvent.give_result(build_conn(player()), event)

      assert conn.private.update_character == nil
    end
  end

  describe "任务物品上交结算（give_command）" do
    setup do
      Items.put("liuxi:task/test", %Item{
        id: "liuxi:task/test",
        name: "素女针 Sunv Zhen",
        verbs: [],
        callback_module: Kantele.World.Item,
        meta: %Meta{owner: "测试", owner_id: "test:npc", unit: "支", value: 10}
      })

      :ok
    end

    test "上交任务物品给对应 NPC：扣物品、发奖励、记 mirror_count" do
      conn = give_in_room(player_with_task(), "测试 inst-task")

      updated = conn.private.update_character || conn.character

      assert updated.inventory == []
      assert updated.meta.stats.mirror_count == 1
      assert updated.meta.stats.combat_exp in 1100..1199
      assert updated.meta.stats.potential in 200..300
      assert updated.meta.stats.silver == 10
      assert output_text(conn) =~ "交给了"
      assert output_text(conn) =~ "第1个宝镜任务"
    end

    test "找错 NPC 不结算" do
      other = %Kalevala.Character{
        id: "test:other",
        name: "路人",
        pid: self(),
        room_id: "test:room",
        meta: %Kantele.Character.NonPlayerMeta{}
      }

      conn = build_conn(player_with_task()) |> Map.put(:room, %{id: "test:room", private: %{characters: [other]}})

      conn = GiveCommand.run(conn, %{"rest" => "测试 inst-task"})

      updated = conn.private.update_character || conn.character
      assert [%Item.Instance{item_id: "liuxi:task/test"}] = updated.inventory
      assert output_text(conn) =~ "这个人不需要这件东西"
    end

    test "第 100 个里程碑：随机掉镜礼不崩溃" do
      for id <- ["liuxi:gift/perwan", "liuxi:gift/kardan", "liuxi:etc/prize4", "liuxi:etc/prize5"] do
        Items.put(id, %Item{id: id, name: "里程碑礼", verbs: [], callback_module: Kantele.World.Item, meta: %Meta{unit: "颗"}})
      end

      p = player_with_task()
      char = %{p | meta: %{p.meta | stats: Map.put(p.meta.stats, :mirror_count, 99)}}

      conn = give_in_room(char, "测试 inst-task")

      updated = conn.private.update_character || conn.character
      assert updated.meta.stats.mirror_count == 100
      assert output_text(conn) =~ "第100个宝镜任务"
    end
  end

  # ---- helpers ----

  defp milestone_ids() do
    [
      "liuxi:gift/perwan",
      "liuxi:gift/kardan",
      "liuxi:etc/prize4",
      "liuxi:etc/prize5",
      "liuxi:gift/str3",
      "liuxi:gift/int3",
      "liuxi:gift/con3",
      "liuxi:gift/dex3",
      "liuxi:item/xuantie",
      "liuxi:etc/bipo",
      "liuxi:etc/huanshi",
      "liuxi:etc/binghuozhu",
      "liuxi:etc/leishenzhu",
      "liuxi:obj/guo",
      "liuxi:max/xuanhuang",
      "liuxi:max/longjia"
    ]
  end

  defp get_item(items, id), do: Enum.find(items, &(&1.id == id))

  defp ask_event(keyword),
    do: %Event{
      topic: "characters/ask",
      data: %{reply_to: self(), asker_id: "player-1", asker_name: "张三", keyword: keyword}
    }

  defp give_event(),
    do: %Event{
      topic: "mirror/give",
      data: %{npc_name: "子虚道人", item_id: "liuxi:item/mirror", asker_id: "player-1"}
    }

  defp player(inventory \\ []) do
    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: inventory,
      meta: %PlayerMeta{
        vitals: Vitals.new(),
        stats: Stats.new(),
        combat: Kantele.Character.Combat.new()
      }
    }
  end

  defp player_with_task() do
    instance = %Item.Instance{id: "inst-task", item_id: "liuxi:task/test", created_at: DateTime.utc_now()}
    player([instance])
  end

  defp give_in_room(char, rest) do
    npc = %Kalevala.Character{
      id: "test:npc",
      name: "测试",
      pid: self(),
      room_id: "test:room",
      meta: %Kantele.Character.NonPlayerMeta{}
    }

    conn = build_conn(char) |> Map.put(:room, %{id: "test:room", private: %{characters: [npc]}})

    GiveCommand.run(conn, %{"rest" => rest})
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end
end