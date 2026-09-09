defmodule Kantele.World.QuestDaemonTest do
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kalevala.Event
  alias Kalevala.World.Item
  alias Kantele.Character.NonPlayerMeta
  alias Kantele.Character.NpcAskEvent
  alias Kantele.World.Items
  alias Kantele.World.QuestDaemon
  alias Kantele.World.Zone
  alias Kantele.World.ZoneCache
  alias Kantele.Quest.Generator

  defp seed_world() do
    item = %Item{id: "test:baozi", name: "包子", description: "白面大包子", meta: %{}}
    Items.put(item.id, item)

    npc1 = %Kalevala.Character{
      id: "test:giver",
      name: "王小二",
      pid: self(),
      room_id: "test:room",
      meta: %Kantele.Character.NonPlayerMeta{}
    }

    npc2 = %Kalevala.Character{
      id: "test:helper",
      name: "李四",
      pid: self(),
      room_id: "test:room",
      meta: %Kantele.Character.NonPlayerMeta{}
    }

    zone = %Zone{
      id: "test",
      name: "测试",
      rooms: %{
        "room" => %{id: "test:room", name: "小屋"},
        "market" => %{id: "test:market", name: "市集"}
      },
      characters: %{"giver" => npc1, "helper" => npc2}
    }

    ZoneCache.put(zone.id, zone)
    {npc1, zone}
  end

  describe "Generator" do
    test "未知类型返回 unknown_type" do
      assert {:error, :unknown_type} = Generator.generate("wizard")
    end

    test "deliver 生成合法任务定义（真实缓存取将）" do
      {_officer, _zone} = seed_world()

      assert {:ok, quest} =
               Generator.generate("deliver", zone_id: "test", item_id: "test:baozi")

      assert quest.id == quest.file
      assert quest.type == "deliver"
      assert is_integer(quest.level) and quest.level in 1..3
      assert quest.limit == 1800
      assert is_binary(quest.officer_npc)
      assert is_binary(quest.target_room)
      assert quest.item_id == "test:baozi"
      assert is_map(quest.rewards) and quest.rewards.exp > 0
      assert is_binary(quest.prompt)
    end
  end

  describe "QuestDaemon" do
    @daemon_opts [name: :anonymous, zone_id: "test", item_id: "test:baozi"]

    setup do
      {_officer, _zone} = seed_world()
      :ok
    end

    test "create 生成并登记，quest_for 按委员分发，finish 移除" do
      pid = start_supervised!({QuestDaemon, @daemon_opts ++ [max_active: 10]})

      {:ok, quest} = QuestDaemon.create(pid, "deliver")

      assert QuestDaemon.get(pid, quest.id) == QuestDaemon.quest_for(pid, quest.officer_npc)
      refute QuestDaemon.quest_for(pid, "test:ghost")

      QuestDaemon.finish(pid, quest.id)
      assert QuestDaemon.get(pid, quest.id) == nil
    end

    test "tick 同步跑一轮：补货 + 过期回收" do
      pid = start_supervised!({QuestDaemon, @daemon_opts ++ [max_active: 3]})

      assert length(QuestDaemon.tick(pid)) == 3
      ids = QuestDaemon.active(pid) |> Enum.map(& &1.id)
      assert Enum.uniq(ids) == ids

      # 注入一条已过期任务（limit -1 → expires_at 落在过去时刻）
      assert {:ok, _} = QuestDaemon.insert(pid, %{id: "qd-expired", type: "deliver", limit: -1})
      assert QuestDaemon.get(pid, "qd-expired")

      # 触发一轮后过期任务被回收
      QuestDaemon.tick(pid)
      assert QuestDaemon.get(pid, "qd-expired") == nil
    end

    test "心跳链式推进：cycle_ms 后自动生成一轮" do
      pid = start_supervised!({QuestDaemon, @daemon_opts ++ [cycle_ms: 30, max_active: 2]})

      Process.sleep(120)
      active = QuestDaemon.active(pid)
      assert length(active) == 2
    end
  end

  describe "NpcAskEvent 开放任务分发" do
    setup do
      {_officer, _zone} = seed_world()
      :ok
    end

    defp daemon_quest(type, npc_id) do
      id = "qd-npc-#{type}-#{npc_id}"

      %{
        id: id,
        file: id,
        type: type,
        level: 1,
        limit: 1800,
        officer_npc: npc_id,
        target_room: "test:room",
        item_id: "test:baozi",
        item_name: "包子",
        count: 1,
        rewards: %{exp: 100, potential: 40, score: 15, coins: 100},
        prompt: "帮我送个包子。"
      }
    end

    defp ask_npc(npc_id) do
      npc = %Kalevala.Character{
        id: npc_id,
        name: "阿婆",
        pid: self(),
        room_id: "test:room",
        meta: %NonPlayerMeta{}
      }

      NpcAskEvent.call(build_conn(npc), %Event{
        topic: "quest/ask",
        data: %{reply_to: self(), asker_id: "player-1", keyword: ""}
      })
    end

    test "deliver 委员分发 turnin-request（可交付结算）" do
      quest = daemon_quest("deliver", "qd-npc:apo")
      QuestDaemon.insert(quest)

      ask_npc("qd-npc:apo")

      assert_receive %Event{topic: "quest/turnin-request", data: data}
      assert data.quest == quest.id
      assert data.item_id == "test:baozi"
      assert data.rewards.exp == 100
      QuestDaemon.finish(quest.id)
    end

    test "search 委员分发 ask-result ok（登记 todo）" do
      quest = daemon_quest("search", "qd-npc:apo")
      QuestDaemon.insert(quest)

      ask_npc("qd-npc:apo")

      assert_receive %Event{topic: "quest/ask-result", data: %{ok: true, quest: spec}}
      assert spec.type == "search"
      assert spec.file == quest.id
      assert spec.master_id == "qd-npc:apo"
      QuestDaemon.finish(quest.id)
    end

    test "无开放任务的 NPC 分发落空" do
      ask_npc("qd-npc:ghost")
      refute_receive %Event{}, 50
    end
  end
end