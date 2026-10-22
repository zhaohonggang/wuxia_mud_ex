defmodule Kantele.Character.NpcAskHostileTest do
  use ExUnit.Case, async: false

  alias Kalevala.Character.Conn
  alias Kalevala.Event
  alias Kantele.Character.NpcAskEvent
  alias Kantele.Character.PlayerMeta

  # ---- 假房间：`NpcAskEvent` 的 hostile 分支经 `Room.npc_characters_by_id/1`
  # 查玩家，必须有一个注册在该 room_id 上的房间进程。 ----

  defmodule FakeRoom do
    use GenServer

    def start_link(state), do: GenServer.start_link(__MODULE__, state)

    @impl true
    def init(state), do: {:ok, state}

    @impl true
    def handle_call({:update, _room}, _from, state), do: {:reply, :ok, state}
    def handle_call({:update_items, _items}, _from, state), do: {:reply, :ok, state}
  end

  defp register_room(room_id, characters) do
    state = %{private: %{characters: characters, item_instances: []}}
    {:ok, pid} = FakeRoom.start_link(state)
    name = {Kalevala.World.Room, room_id}

    previous = :global.whereis_name(name)
    if is_pid(previous), do: :global.unregister_name(name)

    :yes = :global.register_name(name, pid)

    on_exit(fn ->
      :global.unregister_name(name)

      if is_pid(previous) and Process.alive?(previous) do
        :global.register_name(name, previous)
      end
    end)

    pid
  end

  defp unique_room_id, do: "ytest:hostile:#{System.unique_integer([:positive])}"

  defp npc(room_id, inquiries) do
    %Kalevala.Character{
      id: "signature:linzhennan",
      name: "林震南",
      pid: self(),
      room_id: room_id,
      meta: %Kantele.Character.NonPlayerMeta{inquiries: inquiries}
    }
  end

  defp player(room_id) do
    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: room_id,
      meta: %PlayerMeta{}
    }
  end

  defp conn(character) do
    %Conn{
      character: character,
      private: %Conn.Private{
        room: %Kantele.World.Room{id: character.room_id},
        channel_changes: []
      },
      output: []
    }
  end

  defp ask_event(keyword),
    do: %Event{
      topic: "characters/ask",
      data: %{reply_to: self(), asker_id: "player-1", asker_name: "张三", keyword: keyword}
    }

  defp vision_texts(conn) do
    conn.private.channel_changes
    |> Enum.filter(fn
      {:publish, _, event, _, _} when is_map(event) -> event.data.type == "vision"
      _ -> false
    end)
    |> Enum.map(fn {:publish, _, event, _, _} -> event.data.text end)
  end

  describe "hostile 问询" do
    test "广播 vision 文案并触发战斗（kill_ob）" do
      room_id = unique_room_id()
      player = player(room_id)
      register_room(room_id, [player])

      inquiries = %{
        "辟邪剑谱" => %{
          "kind" => "hostile",
          "message" => "林震南大怒，你竟敢窥视林家辟邪剑谱，看我林家剑法！"
        }
      }

      npc = npc(room_id, inquiries)
      conn = NpcAskEvent.call(conn(npc), ask_event("辟邪剑谱"))

      assert Enum.any?(vision_texts(conn), &String.contains?(&1, "林震南大怒"))

      assert_receive %Event{
                       topic: "combat/start",
                       data: %{enemy: %{id: "signature:linzhennan"}, type: "kill"}
                     },
                     200

      refute_receive %Event{topic: "npc/inquiry"}, 100
    end

    test "message 中的 {name} 替换为提问者姓名" do
      room_id = unique_room_id()
      player = player(room_id)
      register_room(room_id, [player])

      inquiries = %{
        "周芷若" => %{"kind" => "hostile", "message" => "{name}你是什么东西？"}
      }

      npc = %{npc(room_id, inquiries) | name: "宋青书"}
      conn = NpcAskEvent.call(conn(npc), ask_event("周芷若"))

      assert Enum.any?(vision_texts(conn), &String.contains?(&1, "张三你是什么东西？"))
      assert_receive %Event{topic: "combat/start"}, 200
    end

    test "玩家不在房间时不崩溃，仍广播文案" do
      room_id = unique_room_id()
      register_room(room_id, [])

      inquiries = %{
        "辟邪剑谱" => %{"kind" => "hostile", "message" => "林震南大怒！"}
      }

      conn = NpcAskEvent.call(conn(npc(room_id, inquiries)), ask_event("辟邪剑谱"))

      assert Enum.any?(vision_texts(conn), &String.contains?(&1, "林震南大怒"))
      refute_receive %Event{topic: "combat/start"}, 100
    end
  end
end
