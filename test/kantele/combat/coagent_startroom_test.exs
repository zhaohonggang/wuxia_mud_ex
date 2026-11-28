defmodule Kantele.Combat.CoagentStartroomTest do
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kalevala.Event
  alias Kantele.Character.Combat
  alias Kantele.Character.CombatEvent
  alias Kantele.Character.NPCConfig
  alias Kantele.Character.NonPlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.Room

  defmodule FakeRoom do
    use GenServer

    def start_link(room_id, chars) do
      :global.unregister_name({Kalevala.World.Room, room_id})

      GenServer.start_link(__MODULE__, {room_id, chars},
        name: {:global, {Kalevala.World.Room, room_id}}
      )
    end

    @impl true
    def init({_room_id, chars}) do
      {:ok,
       %{data: %Room{id: "xiyu:riyuedong"}, private: %{characters: chars, item_instances: []}}}
    end
  end

  @recv_timeout 3000

  defp mate(coagents) do
    %Kalevala.Character{
      id: "mate-1",
      name: "被攻击者",
      pid: self(),
      room_id: "xiyu:riyuedong",
      meta: %NonPlayerMeta{
        vitals: Vitals.new(),
        stats: Stats.new(),
        combat_config: %NPCConfig{spawn_room_id: "xiyu:riyuedong"},
        coagents: coagents,
        combat: Combat.new()
      }
    }
  end

  defp enemy do
    %Kalevala.Character{
      id: "attacker-1",
      name: "攻击者",
      pid: self(),
      room_id: "xiyu:riyuedong"
    }
  end

  defp startroom_event_data do
    %{
      attacker: %{
        id: "attacker-1",
        pid: self(),
        name: "攻击者",
        room_id: "xiyu:riyuedong"
      },
      mate_room: "xiyu:riyuedong",
      mate_id: "mate-1",
      mate_name: "被攻击者"
    }
  end

  setup do
    on_exit(fn ->
      # 清理注册的房间进程
      :global.unregister_name({Kalevala.World.Room, "xiyu:riyuedong"})
      # 清理 ETS 订阅
      :ets.delete(Kantele.Communication.Subscribers, "characters:ding chunqiu")
    end)

    :ok
  end

  test "notify_coagents: 在 startroom 的帮手会收到 coagent/help 事件" do
    coagent_pid = self()

    :ets.insert(Kantele.Communication.Subscribers, {"characters:ding chunqiu", coagent_pid, []})

    {:ok, _room_pid} =
      FakeRoom.start_link("xiyu:riyuedong", [%{pid: coagent_pid, id: "ding chunqiu", name: "丁春秋"}])

    conn = build_conn(mate([%{"id" => "ding chunqiu", "startroom" => "xiyu:riyuedong"}]))

    CombatEvent.start(
      conn,
      %{
        topic: "combat/start",
        data: %{
          enemy: enemy(),
          initiator_id: "other-initiator"
        }
      }
    )

    expected = startroom_event_data()
    assert_receive %Event{topic: "coagent/help", data: ^expected}, @recv_timeout
  end

  test "notify_coagents: 不在 startroom 的帮手不会收到 coagent/help 事件" do
    coagent_pid = self()

    :ets.insert(Kantele.Communication.Subscribers, {"characters:ding chunqiu", coagent_pid, []})

    # 启动 startroom 房间，但 coagent 不在房间内
    {:ok, _room_pid} = FakeRoom.start_link("xiyu:riyuedong", [])

    conn = build_conn(mate([%{"id" => "ding chunqiu", "startroom" => "xiyu:riyuedong"}]))

    CombatEvent.start(
      conn,
      %{
        topic: "combat/start",
        data: %{
          enemy: enemy(),
          initiator_id: "other-initiator"
        }
      }
    )

    assert_raise ExUnit.AssertionError, fn ->
      assert_receive %Event{topic: "coagent/help"}, 500
    end
  end

  test "notify_coagents: 无 startroom 的帮手会收到 coagent/help 事件（旧式行为）" do
    coagent_pid = self()

    :ets.insert(Kantele.Communication.Subscribers, {"characters:ding chunqiu", coagent_pid, []})

    conn = build_conn(mate([%{"id" => "ding chunqiu"}]))

    CombatEvent.start(
      conn,
      %{
        topic: "combat/start",
        data: %{
          enemy: enemy(),
          initiator_id: "other-initiator"
        }
      }
    )

    expected = startroom_event_data()
    assert_receive %Event{topic: "coagent/help", data: ^expected}, @recv_timeout
  end

  test "notify_coagents: 空字符串 startroom 的帮手会收到 coagent/help 事件（旧式行为）" do
    coagent_pid = self()

    :ets.insert(Kantele.Communication.Subscribers, {"characters:ding chunqiu", coagent_pid, []})

    conn = build_conn(mate([%{"id" => "ding chunqiu", "startroom" => ""}]))

    CombatEvent.start(
      conn,
      %{
        topic: "combat/start",
        data: %{
          enemy: enemy(),
          initiator_id: "other-initiator"
        }
      }
    )

    expected = startroom_event_data()
    assert_receive %Event{topic: "coagent/help", data: ^expected}, @recv_timeout
  end

  test "notify_coagents: startroom 房间不存在时帮手不会收到通知" do
    coagent_pid = self()

    :ets.insert(Kantele.Communication.Subscribers, {"characters:ding chunqiu", coagent_pid, []})

    # 不启动房间，npc_characters_by_id 返回 []
    conn = build_conn(mate([%{"id" => "ding chunqiu", "startroom" => "xiyu:riyuedong"}]))

    CombatEvent.start(
      conn,
      %{
        topic: "combat/start",
        data: %{
          enemy: enemy(),
          initiator_id: "other-initiator"
        }
      }
    )

    assert_raise ExUnit.AssertionError, fn ->
      assert_receive %Event{topic: "coagent/help"}, 500
    end
  end
end
