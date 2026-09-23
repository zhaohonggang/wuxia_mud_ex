defmodule Kantele.Character.MoveGreetTest do
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kalevala.Event
  alias Kantele.Character.MoveEvent
  alias Kantele.Character.NonPlayerMeta
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Communication

  @room_id "test:greet-room-#{System.unique_integer([:positive])}"

  setup_all do
    :ok = Communication.register("rooms:#{@room_id}", Kantele.RoomChannel, room_id: @room_id)
    :ok
  end

  setup do
    :ok = Communication.subscribe("rooms:#{@room_id}", [character: %Kalevala.Character{id: "greet-sub", room_id: @room_id}])
    on_exit(fn -> Communication.unsubscribe("rooms:#{@room_id}", [character: %Kalevala.Character{id: "greet-sub", room_id: @room_id}]) end)
    :ok
  end

  defp npc_with_greetings do
    %Kalevala.Character{
      id: "test:xiaoer",
      name: "店小二",
      pid: self(),
      room_id: @room_id,
      inventory: [],
      meta: %NonPlayerMeta{
        zone_id: "test",
        greetings: ["店小二笑咪咪地说道：这位{respect}，进来喝杯茶，歇歇腿吧。"],
        vitals: Vitals.new(),
        stats: Stats.new(),
        combat: Kantele.Character.Combat.new()
      }
    }
  end

  defp player do
    %Kalevala.Character{
      id: "player:1",
      name: "张三",
      pid: self(),
      room_id: @room_id,
      inventory: [],
      meta: %PlayerMeta{
        vitals: Vitals.new(),
        stats: Stats.new(),
        combat: Kantele.Character.Combat.new()
      }
    }
  end

  test "玩家进入有欢迎台词的 NPC 房间：NPC 向房间广播台词" do
    npc = npc_with_greetings()

    move = %Event{
      from_pid: self(),
      topic: Event.Movement.Notice,
      data: %Event.Movement.Notice{
        character: player(),
        direction: :to,
        reason: :enter
      }
    }

    MoveEvent.notice(build_conn(npc), move)

    assert_receive {:room_message, text}
    assert text =~ "店小二"
    refute String.contains?(text, "{respect}")
  end

  test "玩家进程（player:*）不触发欢迎" do
    p = player()
    move = %Event{
      from_pid: self(),
      topic: Event.Movement.Notice,
      data: %Event.Movement.Notice{
        character: player(),
        direction: :to,
        reason: :enter
      }
    }

    MoveEvent.notice(build_conn(p), move)
    refute_receive {:room_message, _}, 100
  end

  test "无 greetings 的 NPC 不触发欢迎" do
    npc = %{
      npc_with_greetings()
      | meta: %{npc_with_greetings().meta | greetings: nil}
    }

    move = %Event{
      from_pid: self(),
      topic: Event.Movement.Notice,
      data: %Event.Movement.Notice{
        character: player(),
        direction: :to,
        reason: :enter
      }
    }

    MoveEvent.notice(build_conn(npc), move)
    refute_receive {:room_message, _}, 100
  end
end