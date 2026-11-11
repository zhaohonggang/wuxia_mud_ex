defmodule Kantele.Character.QuestTurninMultiTest do
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kalevala.Event
  alias Kantele.Character.Combat
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.QuestEvent
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Quest

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
      room_id: Keyword.get(opts, :room_id, "test:room"),
      inventory: inventory,
      meta: %PlayerMeta{
        vitals: Vitals.new(),
        stats: struct(Stats.new(), Keyword.get(opts, :stats, [])),
        combat: Combat.new(),
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

  defp turnin_data(extra \\ %{}) do
    %{
      vendor_name: "阿婆",
      quest: "supply-test",
      item_id: "test:baozi",
      prompt: "请交付包子。",
      rewards: %{exp: 100, potential: 40, score: 15, coins: 100}
    }
    |> Map.merge(extra)
  end

  describe "count>1 逐件交付" do
    test "全部交付一次完成：结算奖励，移出 todo，加已解" do
      p = player(inventory: ["test:baozi", "test:baozi", "test:baozi"])

      {:ok, quests} =
        Quest.set_todo(Quest.new(), %{
          file: "supply-test",
          type: "supply",
          level: 1,
          item: ["test:baozi"],
          count: 3,
          meta: %{}
        })

      p = %{p | meta: PlayerMeta.put_quests(p.meta, quests)}

      conn =
        QuestEvent.turnin_request(build_conn(p), %Event{
          topic: "quest/turnin-request",
          data: turnin_data()
        })

      updated = conn.private.update_character || conn.character

      assert updated.inventory == []
      assert updated.meta.coins == 150
      assert updated.meta.stats.combat_exp == 1215
      refute Map.has_key?(Quest.get_todo_list(updated.meta.quests), "supply-test")
      assert "supply-test" in Quest.get_solved(updated.meta.quests)
      assert Quest.quest_count(updated.meta.quests) == 1
      assert output_text(conn) =~ "任务完成"
    end

    test "部分交付：保留在办，提示还需要几件，不扣奖励" do
      p = player(inventory: ["test:baozi", "test:baozi"])

      {:ok, quests} =
        Quest.set_todo(Quest.new(), %{
          file: "supply-test",
          type: "supply",
          level: 1,
          item: ["test:baozi"],
          count: 5,
          meta: %{}
        })

      p = %{p | meta: PlayerMeta.put_quests(p.meta, quests)}

      conn =
        QuestEvent.turnin_request(build_conn(p), %Event{
          topic: "quest/turnin-request",
          data: turnin_data()
        })

      updated = conn.private.update_character || conn.character

      assert length(updated.inventory) == 0
      assert output_text(conn) =~ "还需要3件"
      assert Quest.get_todo(updated.meta.quests, "supply-test") != nil
      refute "supply-test" in Quest.get_solved(updated.meta.quests)
      assert conn.private.update_character != nil  # 状态已落盘
    end

    test "分两次交付：第二次补齐后结算" do
      p = player(inventory: ["test:baozi", "test:baozi"])

      {:ok, quests} =
        Quest.set_todo(Quest.new(), %{
          file: "supply-test",
          type: "supply",
          level: 1,
          item: ["test:baozi"],
          count: 3,
          meta: %{}
        })

      p = %{p | meta: PlayerMeta.put_quests(p.meta, quests)}

      # 第一次交 2 件，还需要 1 件
      conn1 =
        QuestEvent.turnin_request(build_conn(p), %Event{
          topic: "quest/turnin-request",
          data: turnin_data()
        })

      updated1 = conn1.private.update_character || conn1.character
      assert output_text(conn1) =~ "还需要1件"
      assert Quest.get_todo(updated1.meta.quests, "supply-test") != nil

      # 第二次：包里再放 1 个包子，交齐后结算
      p2 =
        %{
          updated1
          | inventory: [%Kalevala.World.Item.Instance{
            id: "inst-baozi-2",
            item_id: "test:baozi",
            created_at: DateTime.utc_now()
          }]
        }

      conn2 =
        QuestEvent.turnin_request(build_conn(p2), %Event{
          topic: "quest/turnin-request",
          data: turnin_data()
        })

      updated2 = conn2.private.update_character || conn2.character
      assert output_text(conn2) =~ "任务完成"
      refute Map.has_key?(Quest.get_todo_list(updated2.meta.quests), "supply-test")
      assert "supply-test" in Quest.get_solved(updated2.meta.quests)
    end

    test "物品不足：不扣减，只给引导文案，保留在办" do
      p = player()

      {:ok, quests} =
        Quest.set_todo(Quest.new(), %{
          file: "supply-test",
          type: "supply",
          level: 1,
          item: ["test:baozi"],
          count: 5,
          meta: %{}
        })

      p = %{p | meta: PlayerMeta.put_quests(p.meta, quests)}

      conn =
        QuestEvent.turnin_request(build_conn(p), %Event{
          topic: "quest/turnin-request",
          data: turnin_data()
        })

      updated = conn.private.update_character || conn.character

      assert length(updated.inventory) == 0
      assert output_text(conn) =~ "包子"
      assert Quest.get_todo(updated.meta.quests, "supply-test") != nil
      assert conn.private.update_character == nil  # 未发生变更，不落盘
    end

    test "entry 门控：不在 start_room 时拒绝交付" do
      p = player(
        inventory: ["test:baozi", "test:baozi", "test:baozi"],
        room_id: "other:room"
      )

      {:ok, quests} =
        Quest.set_todo(Quest.new(), %{
          file: "supply-test",
          type: "supply",
          level: 1,
          item: ["test:baozi"],
          count: 3,
          start_room: "test:room",
          meta: %{}
        })

      p = %{p | meta: PlayerMeta.put_quests(p.meta, quests)}

      conn =
        QuestEvent.turnin_request(build_conn(p), %Event{
          topic: "quest/turnin-request",
          data: turnin_data()
        })

      assert conn.private.update_character == nil
      assert output_text(conn) =~ "包子"
      assert Quest.get_todo(conn.character.meta.quests, "supply-test") != nil
    end

    test "纯交物路径（无 todo，count=1 默认）：有物品直接结算" do
      p = player(inventory: ["test:baozi"])

      conn =
        QuestEvent.turnin_request(build_conn(p), %Event{
          topic: "quest/turnin-request",
          data: turnin_data(%{quest: ""})
        })

      updated = conn.private.update_character || conn.character
      assert updated.inventory == []
      assert output_text(conn) =~ "任务完成"
    end
  end
end
