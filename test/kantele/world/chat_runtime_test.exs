defmodule Kantele.World.ChatRuntimeTest do
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kalevala.Character.Foreman.Channel
  alias Kantele.Character.NonPlayerMeta
  alias Kantele.Communication

  @room_id "test:chat-room-#{System.unique_integer([:positive])}"

  setup_all do
    :ok = Communication.register("rooms:#{@room_id}", Kantele.RoomChannel, room_id: @room_id)
    :ok
  end

  setup do
    :ok =
      Communication.subscribe("rooms:#{@room_id}", [
        character: %Kalevala.Character{id: "chat-sub", room_id: @room_id}
      ])

    on_exit(fn ->
      Communication.unsubscribe("rooms:#{@room_id}", [
        character: %Kalevala.Character{id: "chat-sub", room_id: @room_id}
      ])
    end)

    :ok
  end

  defp npc do
    %Kalevala.Character{
      id: "test:jinhua",
      name: "金花",
      pid: self(),
      room_id: @room_id,
      inventory: [],
      meta: %NonPlayerMeta{
        zone_id: "test",
        vitals: Kantele.Character.Vitals.new(),
        stats: Kantele.Character.Stats.new(),
        combat: Kantele.Character.Combat.new()
      }
    }
  end

  @chat_lines [
    "金花哭泣着：我的命怎么这么苦哟。",
    "金花抹着眼泪：娘呀，我好想你呀！",
    "金花叹口气说道：不知今生今世能否再见到我娘。"
  ]

  describe "Kantele.Character.ChatAction" do
    test "从台词池随机挑一句以 speech 广播到房间频道" do
      conn =
        npc()
        |> build_conn()
        |> Kantele.Character.ChatAction.run(%{"lines" => @chat_lines})

      Channel.handle_channels(conn, %{communication_module: Communication})

      assert_receive %Kalevala.Event{
        topic: Kalevala.Event.Message,
        data: %Kalevala.Event.Message{type: "speech", text: text}
      }

      assert text in @chat_lines
    end

    test "空台词池不发消息" do
      conn = npc() |> build_conn() |> Kantele.Character.ChatAction.run(%{"lines" => []})

      Channel.handle_channels(conn, %{communication_module: Communication})
      refute_receive %Kalevala.Event{topic: Kalevala.Event.Message}, 100
    end
  end

  describe "Kantele.Brain.Conditions.Random" do
    test "chance=100 必中" do
      assert Kantele.Brain.Conditions.Random.match?(%{}, build_conn(npc()), %{chance: 100})
    end

    test "chance=0 必不中" do
      refute Kantele.Brain.Conditions.Random.match?(%{}, build_conn(npc()), %{chance: 0})
    end
  end

  describe "Loader 挂载" do
    @tag :world_data
    test "jinhua 的 chat_chance/chats 组装为 Random + ChatAction 行为树节点" do
      world = Kantele.World.Loader.load()
      jinhua = Enum.find(world.characters, &String.contains?(&1.name, "金花"))
      assert jinhua != nil

      assert %Kalevala.Brain{
               root: %Kalevala.Brain.Sequence{nodes: [chat, _base]}
             } = jinhua.brain

      assert %Kalevala.Brain.ConditionalSelector{nodes: [cond, action]} = chat

      assert %Kalevala.Brain.Condition{
               type: Kantele.Brain.Conditions.Random,
               data: %{chance: 5}
             } = cond

      assert %Kalevala.Brain.Action{
               type: Kantele.Character.ChatAction,
               data: %{lines: lines}
             } = action

      assert lines == @chat_lines
    end
  end
end