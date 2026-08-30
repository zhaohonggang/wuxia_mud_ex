defmodule Kantele.Character.QuestFamilyTest do
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kalevala.Event
  alias Kantele.Character.FamilyEvent
  alias Kantele.Character.NonPlayerMeta
  alias Kantele.Character.NpcAskEvent
  alias Kantele.Character.NpcFamilyEvent
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.QuestEvent
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Quest

  defp vendor_npc() do
    %Kalevala.Character{
      id: "liuxi:wangshifu",
      name: "王重九",
      pid: self(),
      room_id: "test:room",
      meta: %NonPlayerMeta{
        teach: %{
          family: "柳溪派",
          teach_skills: %{"sword" => %{max: 40, gongxian: 2}},
          no_teach: []
        }
      }
    }
  end

  defp apo_npc() do
    %Kalevala.Character{
      id: "liuxi:apo",
      name: "阿婆",
      pid: self(),
      room_id: "test:room",
      meta: %NonPlayerMeta{
        turn_in: %{
          quest: "song-yupai",
          item: "liuxi:yupai",
          prompt: "阿婆拉着你的手……",
          rumor: "听说有人寻回了血玉牌！",
          rewards: %{exp: 200, potential: 50, score: 10, weiwang: 5, coins: 100}
        }
      }
    }
  end

  defp player(opts \\ []) do
    inventory =
      Enum.map(Keyword.get(opts, :inventory, []), fn item_id ->
        %Kalevala.World.Item.Instance{
          id: "inst-#{item_id}",
          item_id: item_id,
          created_at: DateTime.utc_now()
        }
      end)

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: inventory,
      meta: %PlayerMeta{
        vitals: Vitals.new(),
        stats: struct(Stats.new(), Keyword.get(opts, :stats, [])),
        combat: Kantele.Character.Combat.new(),
        coins: Keyword.get(opts, :coins, 50)
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

  test "拜师：NPC 应允并回门派信息" do
    NpcFamilyEvent.apprentice(build_conn(vendor_npc()), %Event{
      topic: "family/apprentice",
      data: %{reply_to: self(), student_name: "张三"}
    })

    assert_receive %Event{topic: "family/result", data: data}
    assert data.ok == true
    assert data.family == "柳溪派"

    conn = FamilyEvent.result(build_conn(player()), %Event{topic: "family/result", data: data})
    updated = conn.private.update_character || conn.character

    assert updated.meta.family.name == "柳溪派"
    assert updated.meta.family.master_id == "liuxi:wangshifu"
    assert output_text(conn) =~ "柳溪派"
  end

  test "无门派 NPC 婉拒拜师" do
    plain = %{vendor_npc() | meta: %NonPlayerMeta{}}

    NpcFamilyEvent.apprentice(build_conn(plain), %Event{
      topic: "family/apprentice",
      data: %{reply_to: self(), student_name: "张三"}
    })

    assert_receive %Event{topic: "family/result", data: data}
    assert data.ok == false
  end

  test "任务交付：有玉牌则结算奖励（阅历/威望/铜钱）" do
    p =
      player(
        inventory: ["liuxi:yupai"],
        stats: [score: 0, weiwang: 0]
      )

    conn =
      QuestEvent.turnin_request(build_conn(p), %Event{
        topic: "quest/turnin-request",
        data: %{
          vendor_name: "阿婆",
          quest: "song-yupai",
          item_id: "liuxi:yupai",
          prompt: "去把玉牌找回来。",
          rumor: nil,
          rewards: %{exp: 200, potential: 50, score: 10, weiwang: 5, coins: 100}
        }
      })

    updated = conn.private.update_character || conn.character

    assert updated.inventory == []
    assert updated.meta.coins == 150
    assert updated.meta.stats.score == 10
    assert updated.meta.stats.weiwang == 5
    assert output_text(conn) =~ "任务完成"
  end

  test "任务交付：没带物品只给引导文案" do
    conn =
      QuestEvent.turnin_request(build_conn(player()), %Event{
        topic: "quest/turnin-request",
        data: %{
          vendor_name: "阿婆",
          item_id: "liuxi:yupai",
          prompt: "去把玉牌找回来。",
          rewards: %{}
        }
      })

    assert output_text(conn) =~ "玉牌"
    assert conn.private.update_character == nil
  end

  test "阿婆被问话时转出任务请求" do
    NpcAskEvent.call(build_conn(apo_npc()), %Event{
      topic: "characters/ask",
      data: %{reply_to: self(), asker_id: "player-1", asker_name: "张三", keyword: "玉牌"}
    })

    assert_receive %Event{topic: "quest/turnin-request", data: data}
    assert data.item_id == "liuxi:yupai"
  end

  test "任务交付：杀怪要求未满足时拒绝结算（保留玉牌）" do
    p = player(inventory: ["liuxi:yupai"])

    {:ok, quests} = Quest.set_todo(Quest.new(), %{file: "song-yupai", kill: ["yezhu"]})
    p = %{p | meta: PlayerMeta.put_quests(p.meta, quests)}

    conn =
      QuestEvent.turnin_request(build_conn(p), %{topic: "quest/turnin-request", data: %{
        vendor_name: "阿婆",
        quest: "song-yupai",
        item_id: "liuxi:yupai",
        prompt: "去把进山的野猪除掉，寻回玉牌。",
        rewards: %{exp: 200, potential: 50, score: 10, weiwang: 5, coins: 100}
      }})

    assert conn.private.update_character == nil
    assert output_text(conn) =~ "野猪"
    assert length(conn.character.inventory) == 1
  end

  test "任务交付：杀怪要求满足后结算成功" do
    p = player(inventory: ["liuxi:yupai"])

    {:ok, quests} = Quest.set_todo(Quest.new(), %{file: "song-yupai", kill: ["yezhu"]})

    {:ok, quests} =
      Quest.add_killed(quests, %{file: "song-yupai", kill: ["yezhu"]}, "yezhu", 1)

    p = %{p | meta: PlayerMeta.put_quests(p.meta, quests)}

    conn =
      QuestEvent.turnin_request(build_conn(p), %{topic: "quest/turnin-request", data: %{
        vendor_name: "阿婆",
        quest: "song-yupai",
        item_id: "liuxi:yupai",
        prompt: "去把进山的野猪除掉，寻回玉牌。",
        rewards: %{exp: 200, potential: 50, score: 10, weiwang: 5, coins: 100}
      }})

    updated = conn.private.update_character || conn.character
    assert updated.inventory == []
    assert updated.meta.coins == 150
    assert output_text(conn) =~ "任务完成"
  end
end
