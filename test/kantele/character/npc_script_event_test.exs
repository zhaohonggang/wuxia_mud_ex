defmodule Kantele.Character.NpcScriptEventTest do
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kalevala.Event
  alias Kalevala.World.Item
  alias Kantele.Character.NpcAskEvent
  alias Kantele.Character.NpcScriptEvent
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.Item.Meta
  alias Kantele.World.Items

  describe "脚本化问询分发（NpcAskEvent）" do
    test "give 脚本 → npc/give 事件回玩家" do
      npc = npc(%{"铸剑" => %{"reply" => "收好这块精钢。\n", "give" => "signature:jinggang"}})

      conn = NpcAskEvent.call(build_conn(npc), ask_event("铸剑"))

      assert conn != nil

      assert_receive %Event{
        topic: "npc/give",
        data: %{npc_name: "干将", item_id: "signature:jinggang", asker_id: "player-1"}
      }
    end

    test "learn_skill 脚本 → npc/learn 事件" do
      npc = npc(%{"道法" => %{"reply" => "且听。\n", "learn_skill" => "taoism"}})

      NpcAskEvent.call(build_conn(npc), ask_event("道法"))

      assert_receive %Event{
        topic: "npc/learn",
        data: %{skill: "taoism", asker_id: "player-1"}
      }
    end

    test "family 脚本 → npc/faction 事件（带 gongxian）" do
      npc = npc(%{"拜师" => %{"reply" => "入门吧。\n", "family" => "青阳门", "gongxian" => 10}})

      NpcAskEvent.call(build_conn(npc), ask_event("拜师"))

      assert_receive %Event{
        topic: "npc/faction",
        data: %{family: "青阳门", gongxian: 10, asker_id: "player-1"}
      }
    end

    test "纯文本问询保持原有行为（不进脚本分支）" do
      npc = npc(%{"莫邪" => "她是吾妻。\n"})

      NpcAskEvent.call(build_conn(npc), ask_event("莫邪"))

      refute_receive %Event{topic: "npc/give"}, 100
      refute_receive %Event{topic: "npc/learn"}, 100
      refute_receive %Event{topic: "npc/faction"}, 100
    end
  end

  describe "玩家侧领物（NpcScriptEvent.npc/give）" do
    setup do
      Items.put("signature:jinggang", %Item{
        id: "signature:jinggang",
        name: "精钢块 Steel Ingot",
        verbs: [],
        callback_module: Kantele.World.Item,
        meta: %Meta{weight: 100, value: 500}
      })

      :ok
    end

    test "给物入背包并渲染回话" do
      conn = NpcScriptEvent.give_result(build_conn(player()), give_event())

      updated = conn.private.update_character || conn.character

      assert [%Item.Instance{item_id: "signature:jinggang"}] = updated.inventory
      assert output_text(conn) =~ "递到你手中"
    end

    test "它人领物事件不处理" do
      event = %{give_event() | data: %{give_event().data | asker_id: "someone"}}
      conn = NpcScriptEvent.give_result(build_conn(player()), event)

      assert conn.private.update_character == nil
    end
  end

  describe "玩家侧传技（NpcScriptEvent.npc/learn）" do
    test "学会新技能（stats.skills 首学 1 级）" do
      conn = NpcScriptEvent.learn_result(build_conn(player()), learn_event())

      updated = conn.private.update_character || conn.character

      assert updated.meta.stats.skills["taoism"] == 1
      assert output_text(conn) =~ "领悟了「taoism」"
    end
  end

  describe "玩家侧拜师（NpcScriptEvent.npc/faction）" do
    test "写入 family 并发放门派贡献" do
      conn = NpcScriptEvent.faction_result(build_conn(player()), faction_event())

      updated = conn.private.update_character || conn.character

      assert updated.meta.family.name == "青阳门"
      assert updated.meta.stats.gongxian == 10
      assert output_text(conn) =~ "青阳门"
    end
  end

  # ---- helpers ----

  defp npc(inquiries) do
    %Kalevala.Character{
      id: "signature:ganjiang",
      name: "干将",
      pid: self(),
      room_id: "test:room",
      meta: %Kantele.Character.NonPlayerMeta{inquiries: inquiries}
    }
  end

  defp ask_event(keyword),
    do: %Event{
      topic: "characters/ask",
      data: %{reply_to: self(), asker_id: "player-1", asker_name: "张三", keyword: keyword}
    }

  defp give_event(),
    do: %Event{
      topic: "npc/give",
      data: %{npc_name: "干将", item_id: "signature:jinggang", asker_id: "player-1"}
    }

  defp learn_event(),
    do: %Event{
      topic: "npc/learn",
      data: %{npc_name: "青阳子", skill: "taoism", asker_id: "player-1"}
    }

  defp faction_event(),
    do: %Event{
      topic: "npc/faction",
      data: %{npc_name: "青阳子", family: "青阳门", gongxian: 10, asker_id: "player-1"}
    }

  defp player() do
    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      meta: %PlayerMeta{
        vitals: Vitals.new(),
        stats: Stats.new(),
        combat: Kantele.Character.Combat.new()
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
end