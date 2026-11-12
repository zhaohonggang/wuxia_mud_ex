defmodule Kantele.World.DoorTest.FakeRoom do
  @moduledoc """
  `{:global, {Kalevala.World.Room, room_id}}` 最小替身，供 Door 框架单测。
  同 `RoomActions.OpenCloseTest.FakeRoom`：只注册一次，`setup` 复位 state。
  """
  use GenServer

  def start_link({room_id, opts}) do
    GenServer.start_link(__MODULE__, {room_id, opts},
      name: {:global, {Kalevala.World.Room, room_id}}
    )
  end

  def reset(room_id) do
    case :global.whereis_name({Kalevala.World.Room, room_id}) do
      pid when is_pid(pid) -> GenServer.call(pid, :reset)
      _ -> :ok
    end
  end

  def set_door_state(room_id, dir, door_state) do
    case :global.whereis_name({Kalevala.World.Room, room_id}) do
      pid when is_pid(pid) -> GenServer.call(pid, {:set_door_state, dir, door_state})
      _ -> :ok
    end
  end

  @impl true
  def init({room_id, _opts}) do
    {:ok,
     %{
       data: %Kantele.World.Room{id: room_id, state: %{}},
       private: %{characters: [], item_instances: []}
     }}
  end

  @impl true
  def handle_call(:reset, _from, state) do
    Enum.each(state.data.state || %{}, fn
      {"exit_timer:" <> _key, tref} -> :timer.cancel(tref)
      _other -> :ok
    end)

    {:reply, :ok,
     %{
       data: %Kantele.World.Room{id: state.data.id, state: %{}},
       private: %{characters: [], item_instances: []}
     }}
  end

  def handle_call({:set_door_state, dir, door_state}, _from, state) do
    key = "door:" <> dir

    {:reply, :ok,
     %{state | data: %{state.data | state: Map.put(state.data.state, key, door_state)}}}
  end
end

defmodule Kantele.World.DoorTest do
  @moduledoc """
  P5-6 门/容器统一框架 `Kantele.World.Door` 单测。

  覆盖点：
  - 门状态读写（缺省 / 自定义）
  - open? / locked? 判断
  - open/close：出口增删、邻房同步、门状态更新、自动关门登记/取消
  - lock/unlock：锁定拒绝打开、解锁恢复
  - valid_leave：passthrough / deny / allow
  """

  use ExUnit.Case, async: false

  alias Kalevala.Character.Conn
  alias Kantele.World.Door
  alias Kantele.World.Room
  alias Kantele.World.RoomActions.DynamicExit
  alias Kantele.World.DoorTest.FakeRoom

  @self_room "door:test_room_a"
  @neighbor_room "door:test_room_b"
  @self_dir "north"
  @neighbor_dir "south"

  @room_ids [@self_room, @neighbor_room]

  setup_all do
    pids =
      for room_id <- @room_ids do
        :global.unregister_name({Kalevala.World.Room, room_id})
        {:ok, pid} = FakeRoom.start_link({room_id, []})
        pid
      end

    on_exit(fn ->
      Enum.each(pids, fn pid ->
        if Process.alive?(pid), do: GenServer.stop(pid)
      end)
    end)

    :ok
  end

  setup do
    Enum.each(@room_ids, &FakeRoom.reset/1)
    :ok
  end

  # ---- conn helper ---------------------------------------------------------

  defp conn(room_id \\ @self_room) do
    character = %Kalevala.Character{
      id: "test-player",
      name: "玩家",
      room_id: room_id,
      attributes: %{"wiz_level" => 0},
      meta: %Kantele.Character.PlayerMeta{temp: %{}},
      inventory: []
    }

    %Conn{
      character: character,
      private: %Conn.Private{channel_changes: []},
      output: []
    }
  end

  defp exit_target(room_id, dir) do
    case :global.whereis_name({Kalevala.World.Room, room_id}) do
      pid when is_pid(pid) ->
        pid
        |> :sys.get_state()
        |> Map.get(:data)
        |> Map.get(:exits)
        |> List.wrap()
        |> Enum.find_value(fn exit ->
          if Map.get(exit, :exit_name) == dir, do: Map.get(exit, :end_room_id)
        end)

      _ ->
        nil
    end
  end

  # ---- 门状态读写 ----------------------------------------------------------

  describe "门状态" do
    test "缺省状态：未开、未锁、无自动关门、无 timer_key" do
      assert Door.state(@self_room, @self_dir) ==
               %Door{open?: false, locked?: false, auto_close_ms: nil, timer_key: nil}
    end

    test "state/2 读取已写入的自定义门状态" do
      FakeRoom.set_door_state(@self_room, @self_dir, %Door{
        open?: true,
        locked?: true,
        auto_close_ms: 5000,
        timer_key: "k"
      })

      assert Door.state(@self_room, @self_dir) ==
               %Door{open?: true, locked?: true, auto_close_ms: 5000, timer_key: "k"}
    end

    test "不存在的房间/方向返回缺省状态" do
      assert Door.state("door:nonexistent", "north") ==
               %Door{open?: false, locked?: false, auto_close_ms: nil, timer_key: nil}
    end
  end

  # ---- open? / locked? -----------------------------------------------------

  describe "open? / locked?" do
    test "未设出口时 open? 为 false" do
      refute Door.open?(@self_room, @self_dir)
    end

    test "open 后 open? 为 true；close 后为 false" do
      Door.open(conn(), @self_room, @self_dir, @neighbor_room, nil,
        neighbor_room: @neighbor_room,
        neighbor_dir: @neighbor_dir
      )

      assert Door.open?(@self_room, @self_dir)
      assert Door.open?(@neighbor_room, @neighbor_dir)

      Door.close(conn(), @self_room, @self_dir, nil,
        neighbor_room: @neighbor_room,
        neighbor_dir: @neighbor_dir
      )

      refute Door.open?(@self_room, @self_dir)
      refute Door.open?(@neighbor_room, @neighbor_dir)
    end

    test "lock/lock?/unlock 闭环" do
      refute Door.locked?(@self_room, @self_dir)

      :ok = Door.lock(@self_room, @self_dir)
      assert Door.locked?(@self_room, @self_dir)

      :ok = Door.unlock(@self_room, @self_dir)
      refute Door.locked?(@self_room, @self_dir)
    end
  end

  # ---- open/close ----------------------------------------------------------

  describe "open/close" do
    test "open 单向门：设出口、更新状态、不碰邻房" do
      {:ok, _conn} = Door.open(conn(), @self_room, @self_dir, @neighbor_room, nil)

      assert DynamicExit.open?(@self_room, @self_dir)
      assert exit_target(@self_room, @self_dir) == @neighbor_room
      assert Door.state(@self_room, @self_dir).open? == true
      refute DynamicExit.open?(@neighbor_room, @neighbor_dir)
    end

    test "open 双向门：两边出口同时打通 + 邻房广播" do
      subscribe_room(@neighbor_room)

      {:ok, _conn} =
        Door.open(conn(), @self_room, @self_dir, @neighbor_room, nil,
          neighbor_room: @neighbor_room,
          neighbor_dir: @neighbor_dir,
          neighbor_vision: "大门从外面被打开了。\n"
        )

      assert DynamicExit.open?(@self_room, @self_dir)
      assert DynamicExit.open?(@neighbor_room, @neighbor_dir)
      assert exit_target(@self_room, @self_dir) == @neighbor_room
      assert exit_target(@neighbor_room, @neighbor_dir) == @self_room

      assert_received {:room_message, "大门从外面被打开了。\n"},
                      200
    end

    test "open 已开的门返回 {:error, :already_open}，不动出口" do
      Door.open(conn(), @self_room, @self_dir, @neighbor_room, nil)

      result = Door.open(conn(), @self_room, @self_dir, @neighbor_room, nil)
      assert result == {:error, :already_open}
      assert DynamicExit.open?(@self_room, @self_dir)
    end

    test "open 锁定的门返回 {:error, :locked}，不动出口" do
      Door.lock(@self_room, @self_dir)

      result = Door.open(conn(), @self_room, @self_dir, @neighbor_room, nil)
      assert result == {:error, :locked}
      refute DynamicExit.open?(@self_room, @self_dir)
    end

    test "close 已关的门返回 {:error, :already_closed}" do
      result = Door.close(conn(), @self_room, @self_dir, nil)
      assert result == {:error, :already_closed}
    end

    test "close 双向门：两边出口都删 + 取消定时器 + 更新状态" do
      Door.open(conn(), @self_room, @self_dir, @neighbor_room, nil,
        neighbor_room: @neighbor_room,
        neighbor_dir: @neighbor_dir,
        auto_close_ms: 10_000,
        timer_key: "exit_timer:door:test"
      )

      assert DynamicExit.open?(@self_room, @self_dir)
      assert DynamicExit.open?(@neighbor_room, @neighbor_dir)

      {:ok, _conn} =
        Door.close(conn(), @self_room, @self_dir, nil,
          neighbor_room: @neighbor_room,
          neighbor_dir: @neighbor_dir
        )

      refute DynamicExit.open?(@self_room, @self_dir)
      refute DynamicExit.open?(@neighbor_room, @neighbor_dir)
      assert Door.state(@self_room, @self_dir).open? == false
      assert Door.state(@self_room, @self_dir).timer_key == nil
    end
  end

  # ---- 自动关门 ------------------------------------------------------------

  describe "自动关门" do
    test "schedule_auto_close / cancel_auto_close 闭环" do
      :ok =
        Door.schedule_auto_close(5_000, @self_room, "exit_timer:test", [
          {@self_room, @self_dir, nil}
        ])

      assert Room.get_state_by_id(@self_room, "exit_timer:test") != nil

      :ok = Door.cancel_auto_close(@self_room, "exit_timer:test")
      assert Room.get_state_by_id(@self_room, "exit_timer:test") == nil
    end

    test "open 带 auto_close_ms 会把 timer_key 写进门状态" do
      {:ok, _conn} =
        Door.open(conn(), @self_room, @self_dir, @neighbor_room, nil,
          neighbor_room: @neighbor_room,
          neighbor_dir: @neighbor_dir,
          auto_close_ms: 10_000
        )

      assert is_binary(Door.state(@self_room, @self_dir).timer_key)
      assert Room.get_state_by_id(@self_room, Door.state(@self_room, @self_dir).timer_key) != nil
    end

    test "close 会取消自动关门定时器" do
      {:ok, _conn} =
        Door.open(conn(), @self_room, @self_dir, @neighbor_room, nil, auto_close_ms: 10_000)

      timer_key = Door.state(@self_room, @self_dir).timer_key
      assert timer_key != nil
      assert Room.get_state_by_id(@self_room, timer_key) != nil

      Door.close(conn(), @self_room, @self_dir, nil)
      assert Room.get_state_by_id(@self_room, timer_key) == nil
    end
  end

  # ---- valid_leave ---------------------------------------------------------

  describe "valid_leave" do
    test "门不存在或已开时返回 :passthrough" do
      assert Door.valid_leave(@self_room, @self_dir, "test-player") == {:passthrough}

      Door.open(conn(), @self_room, @self_dir, @neighbor_room, nil)
      assert Door.valid_leave(@self_room, @self_dir, "test-player") == {:passthrough}
    end

    test "门关且锁定，允许名单内 -> {:allow}" do
      Door.lock(@self_room, @self_dir)

      assert Door.valid_leave(@self_room, @self_dir, "test-player", ["test-player"], []) ==
               {:allow, "请进。\n"}
    end

    test "门关且锁定，拒绝名单内 -> {:deny}" do
      Door.lock(@self_room, @self_dir)

      assert Door.valid_leave(@self_room, @self_dir, "test-player", [], ["test-player"]) ==
               {:deny, "门锁着，你进不去。\n"}
    end

    test "门关且锁定，名单都不在 -> {:deny}" do
      Door.lock(@self_room, @self_dir)

      assert Door.valid_leave(@self_room, @self_dir, "other", ["test-player"], []) ==
               {:deny, "门锁着，非请莫入。\n"}
    end

    test "拒绝名单优先级高于允许名单" do
      Door.lock(@self_room, @self_dir)

      assert Door.valid_leave(@self_room, @self_dir, "test-player", ["test-player"], [
               "test-player"
             ]) ==
               {:deny, "门锁着，你进不去。\n"}
    end
  end

  # ---- helpers -------------------------------------------------------------

  defp subscribe_room(room_id) do
    channel = "rooms:#{room_id}"

    case Kantele.Communication.register(channel, Kantele.RoomChannel, room_id: room_id) do
      :ok -> :ok
      {:error, :already_registered} -> :ok
    end

    :ok =
      Kantele.Communication.subscribe(channel,
        character: %Kalevala.Character{id: "test-subscriber", room_id: room_id}
      )
  end
end
