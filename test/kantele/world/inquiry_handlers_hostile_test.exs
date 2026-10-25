defmodule Kantele.World.InquiryHandlers.HostileTest do
  @moduledoc """
  P5-R23：问询触怒 NPC 直接开打（kind = "hostile"），镜像 LPC
  `d/fuzhou/npc/linzhennan.c` `ask_pixie()` 与
  `d/emei/npc/songqingshu.c` `ask_for_zhou()`。

  覆盖：kind 注册 / asker 守门 / message 缺省静默 / message_vision 放话 +
  combat/start 双方 / say + emote 链与 `{name}` 占位替换 / 无房间时不广播仍开打。
  """

  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Vitals
  alias Kantele.World.InquiryHandlers
  alias Kantele.World.InquiryHandlers.Hostile

  defp conn(opts \\ []) do
    meta = %PlayerMeta{
      vitals: Keyword.get(opts, :vitals, %Vitals{qi: 100})
    }

    %Conn{
      character: %Kalevala.Character{
        id: "player:test",
        name: "测试玩家",
        room_id: Keyword.get(opts, :room_id, "fuzhou:pingying"),
        meta: meta
      },
      private: %Conn.Private{channel_changes: []},
      output: []
    }
  end

  # 林震南场景（LPC message_vision，无 say/emote）
  defp lin_data(overrides \\ %{}) do
    Map.merge(
      %{
        kind: "hostile",
        config: %{
          "message" => "林震南大怒，你竟敢窥视林家辟邪剑谱，看我林家剑法！"
        },
        npc_id: "npc-lin",
        npc_name: "林震南",
        npc_pid: self(),
        npc_room_id: "fuzhou:pingying",
        asker_id: "player:test"
      },
      overrides
    )
  end

  # 宋青书场景（LPC command("heng") + command("say ...")）
  defp song_data(overrides \\ %{}) do
    Map.merge(
      %{
        kind: "hostile",
        config: %{
          "message" => "{name}你是什么东西？敢直呼芷若的名字？",
          "say" => true,
          "emote" => "哼了一声"
        },
        npc_id: "npc-song",
        npc_name: "宋青书",
        npc_pid: self(),
        npc_room_id: "emei:lingjiu",
        asker_id: "player:test"
      },
      overrides
    )
  end

  defp publishes(conn) do
    Enum.filter(conn.private.channel_changes, fn
      {:publish, "rooms:" <> _, _, _, _} -> true
      _ -> false
    end)
    |> Enum.map(fn {:publish, _channel, event, _options, _fun} -> event.data.text end)
  end

  describe "run/3 守门" do
    test "kind 已注册（InquiryHandlers.lookup）" do
      assert InquiryHandlers.lookup("hostile") == Hostile
    end

    test "asker 不匹配 → 静默（无广播、无战斗事件）" do
      conn2 = Hostile.run(conn(), lin_data().config, lin_data(%{asker_id: "player:other"}))

      assert publishes(conn2) == []
      refute_received %Kalevala.Event{topic: "combat/start"}
    end

    test "message 缺省 → 静默" do
      data = lin_data(%{config: %{"say" => true}})
      conn2 = Hostile.run(conn(), data.config, data)

      assert publishes(conn2) == []
      refute_received %Kalevala.Event{topic: "combat/start"}
    end
  end

  describe "林震南（message_vision + kill_ob）" do
    test "房间广播放话原文" do
      data = lin_data()
      conn2 = Hostile.run(conn(), data.config, data)

      assert publishes(conn2) == ["林震南大怒，你竟敢窥视林家辟邪剑谱，看我林家剑法！\n"]
    end

    test "给问者发 combat/start（enemy 为 NPC）" do
      data = lin_data()
      Hostile.run(conn(), data.config, data)

      assert_receive %Kalevala.Event{
        topic: "combat/start",
        data: %{type: "kill", enemy: %{id: "npc-lin", name: "林震南"}}
      }, 200
    end

    test "给 NPC 发 combat/start（enemy 为问者）" do
      data = lin_data()
      Hostile.run(conn(), data.config, data)

      assert_receive %Kalevala.Event{
        topic: "combat/start",
        data: %{type: "kill", enemy: %{id: "player:test"}}
      }, 200
    end

    test "不私发任何文本（LPC return -1）" do
      data = lin_data()
      conn2 = Hostile.run(conn(), data.config, data)

      assert conn2.output == []
    end
  end

  describe "宋青书（heng + say + kill_ob）" do
    test "先播 emote、再播 say，say 前缀 NPC 名" do
      data = song_data()
      conn2 = Hostile.run(conn(), data.config, data)

      # `Conn.publish_message` 把新变更 **prepend** 到 channel_changes，
      # 故列表是「后发生的在前」：调用序 emote → say，断言序 say → emote。
      assert publishes(conn2) == [
               "宋青书说道：测试玩家你是什么东西？敢直呼芷若的名字？\n",
               "宋青书哼了一声。\n"
             ]
    end

    test "互相开战" do
      data = song_data()
      Hostile.run(conn(), data.config, data)

      assert_receive %Kalevala.Event{topic: "combat/start", data: %{type: "kill"}}, 200
      assert_receive %Kalevala.Event{topic: "combat/start", data: %{type: "kill"}}, 200
    end

    test "say 缺省 → 裸播 message（仍替换 {name}）" do
      data = song_data(%{config: %{"message" => "{name}哼什么哼？"}})
      conn2 = Hostile.run(conn(), data.config, data)

      assert publishes(conn2) == ["测试玩家哼什么哼？\n"]
    end
  end

  describe "降级" do
    test "npc_room_id 缺失 → 不广播但仍开打" do
      data = lin_data(%{npc_room_id: nil})
      conn2 = Hostile.run(conn(), data.config, data)

      assert publishes(conn2) == []
      assert_receive %Kalevala.Event{topic: "combat/start", data: %{type: "kill"}}, 200
    end
  end
end
