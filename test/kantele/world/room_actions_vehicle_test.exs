defmodule Kantele.World.RoomActions.VehicleTest.FakeRoom do
  @moduledoc """
  `{:global, {Kalevala.World.Room, room_id}}` 最小替身（同 `KnockPullTest`）。

  与 knock/pull 不同的是：本载具链路的定时器 tref 存进房间 state 的键形如
  `"vehicle:<room>:<step>"`（不是 `"exit_timer:"` 前缀），故 reset 时显式取消所有
  `{:timer, _}` 形态的 tref，避免上一测试的迟到定时器在房间被 reset 后重新写入出口、
  污染后续测试。
  """
  use GenServer

  def start_link({room_id, _opts}) do
    GenServer.start_link(__MODULE__, {room_id, []},
      name: {:global, {Kalevala.World.Room, room_id}}
    )
  end

  def reset(room_id) do
    case :global.whereis_name({Kalevala.World.Room, room_id}) do
      pid when is_pid(pid) -> GenServer.call(pid, :reset)
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
      {_key, {:once, _} = tref} -> :timer.cancel(tref)
      {_key, {:timer, _} = tref} -> :timer.cancel(tref)
      _other -> :ok
    end)

    {:reply, :ok,
     %{
       data: %Kantele.World.Room{id: state.data.id, state: %{}},
       private: %{characters: [], item_instances: []}
     }}
  end
end

defmodule Kantele.World.RoomActions.VehicleTest do
  @moduledoc """
  P5-8 / 通信中继·载具：`on_board` 定时载具（heimuya 吊篮 + guiyun 渡船）移植测试。

  链路（LPC `check_trigger → on_board → arrive → close_passage`）：
  - 触发：玩家在 up2/up3/taihu/matou 触发载具，中转房 basket/duchuan 出现双向出口、
    置位 trigger_flag、排 on_board 定时器。
  - on_board：删触发房→中转出口 + 中转→触发出口，排 arrive。
  - arrive：设中转→下一程（dest）出口，排 close_passage。
  - close_passage：删中转出口、清 trigger_flag。

  测试用 FakeRoom（`{:sys.replace_state}` 兼容 `Room.set_exit/put_state_by_id` 等）
  + 缩短后的定时（20/20/20ms）跑完整链路；触发链路的「已停靠/在途」两种门控亦覆盖。
  """
  use ExUnit.Case, async: false

  alias Kalevala.Character.Conn
  alias Kalevala.Character.Conn.Private
  alias Kantele.Character.PlayerMeta
  alias Kantele.World.Room
  alias Kantele.World.RoomActionHandlers
  alias Kantele.World.RoomActions.Vehicle
  alias Kantele.World.RoomActions.Vehicle.Trigger
  alias Kantele.World.RoomActions.VehicleTest.FakeRoom

  @fast_timings %{on_board: 20, arrive: 20, close: 20}

  @room_ids [
    # 触发房
    "heimuya:up2",
    "heimuya:up3",
    "guiyun:taihu",
    "guiyun:matou",
    # 中转房
    "heimuya:basket",
    "guiyun:duchuan"
  ]

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

  # ---- 注册表 ---------------------------------------------------------------

  describe "注册表" do
    test "四间触发房都挂了对应的载具动词" do
      assert RoomActionHandlers.lookup("heimuya:up2", "do_insert") ==
               {:ok, {Trigger, :run}}

      assert RoomActionHandlers.lookup("heimuya:up3", "do_insert") ==
               {:ok, {Trigger, :run}}

      assert RoomActionHandlers.lookup("guiyun:taihu", "do_yell") ==
               {:ok, {Trigger, :run}}

      assert RoomActionHandlers.lookup("guiyun:taihu", "do_cross") ==
               {:ok, {Trigger, :run}}

      assert RoomActionHandlers.lookup("guiyun:matou", "do_yell") ==
               {:ok, {Trigger, :run}}

      assert RoomActionHandlers.lookup("guiyun:matou", "do_cross") ==
               {:ok, {Trigger, :run}}

      assert RoomActionHandlers.lookup("guiyun:matou", "do_shang") ==
               {:ok, {Trigger, :run}}
    end
  end

  # ---- 黑木崖吊篮（up2 → basket → up3） ------------------------------------

  describe "heimuya:up2 吊篮（短定时跑完整链路）" do
    test "触发后：双向出口就位 + trigger_flag 置位" do
      cfg = Trigger.config("heimuya:up2") |> Map.put(:timings, @fast_timings)
      conn = Vehicle.check_trigger(conn("heimuya:up2"), "heimuya:up2", cfg)

      assert conn.private.channel_changes != []
      assert Room.has_exit_by_id?("heimuya:up2", "enter")
      assert Room.has_exit_by_id?("heimuya:basket", "out")
      assert exit_target("heimuya:basket", "out") == "heimuya:up2"
      assert Room.get_state_by_id("heimuya:basket", "vehicle:heimuya_basket") == 1
    end

    test "跑完四步：出口全部回收 + flag 清除（玩家被送达 up3）" do
      cfg = Trigger.config("heimuya:up2") |> Map.put(:timings, @fast_timings)
      Vehicle.check_trigger(conn("heimuya:up2"), "heimuya:up2", cfg)

      Process.sleep(200)

      refute Room.has_exit_by_id?("heimuya:up2", "enter")
      refute Room.has_exit_by_id?("heimuya:basket", "out")
      assert Room.get_state_by_id("heimuya:basket", "vehicle:heimuya_basket") == nil
    end
  end

  describe "Vehicle 定时回调（直接单元，免定时竞态）" do
    test "on_board：删 enter + 中转out，排 arrive 定时器" do
      cfg = Trigger.config("heimuya:up2")
      Room.set_exit("heimuya:up2", "enter", "heimuya:basket")
      Room.set_exit("heimuya:basket", "out", "heimuya:up2")

      Vehicle.on_board("heimuya:up2", cfg)

      refute Room.has_exit_by_id?("heimuya:up2", "enter")
      refute Room.has_exit_by_id?("heimuya:basket", "out")
      assert {:once, _} = Room.get_state_by_id("heimuya:basket", "vehicle:heimuya:up2:arrive")
    end

    test "arrive：中转out 指向 dest（up3），排 close_passage 定时器" do
      cfg = Trigger.config("heimuya:up2")
      Vehicle.arrive("heimuya:basket", cfg)

      assert Room.has_exit_by_id?("heimuya:basket", "out")
      assert exit_target("heimuya:basket", "out") == "heimuya:up3"
      assert {:once, _} = Room.get_state_by_id("heimuya:basket", "vehicle:heimuya:up2:close_passage")
    end

    test "close_passage：删中转out + 清 trigger_flag" do
      cfg = Trigger.config("heimuya:up2")
      Room.set_exit("heimuya:basket", "out", "heimuya:up3")
      Room.put_state_by_id("heimuya:basket", "vehicle:heimuya_basket", 1)

      Vehicle.close_passage("heimuya:basket", cfg)

      refute Room.has_exit_by_id?("heimuya:basket", "out")
      assert Room.get_state_by_id("heimuya:basket", "vehicle:heimuya_basket") == nil
    end
  end

  describe "heimuya:up2 门控" do
    test "载具已停靠（enter 出口存在）→ 不启动链路（无 already_vision）" do
      Room.set_exit("heimuya:up2", "enter", "heimuya:basket")
      cfg = Trigger.config("heimuya:up2") |> Map.put(:timings, @fast_timings)
      conn = Vehicle.check_trigger(conn("heimuya:up2"), "heimuya:up2", cfg)

      # heimuya 无 already_vision，故无广播
      assert published(conn) == []
      # 链路未启动：flag 未置位、enter 出口保持原样
      refute Room.get_state_by_id("heimuya:basket", "vehicle:heimuya_basket")
      assert Room.has_exit_by_id?("heimuya:up2", "enter")
    end

    test "载具在途（trigger_flag 已置）→ 不启动链路，广播 busy_vision" do
      Room.put_state_by_id("heimuya:basket", "vehicle:heimuya_basket", 1)
      cfg = Trigger.config("heimuya:up2") |> Map.put(:timings, @fast_timings)
      conn = Vehicle.check_trigger(conn("heimuya:up2"), "heimuya:up2", cfg)

      assert published(conn) == ["看样子你得等下拨儿。\n"]
      refute Room.has_exit_by_id?("heimuya:up2", "enter")
      assert Room.get_state_by_id("heimuya:basket", "vehicle:heimuya_basket") == 1
    end
  end

  # ---- 归云庄渡船（taihu ↔ matou via duchuan） -----------------------------

  describe "guiyun:taihu 渡船（短定时跑完整链路）" do
    test "触发后：双向出口就位 + trigger_flag 置位 + trigger_vision 广播" do
      cfg = Trigger.config("guiyun:taihu") |> Map.put(:timings, @fast_timings)
      conn = Vehicle.check_trigger(conn("guiyun:taihu"), "guiyun:taihu", cfg)

      assert published(conn) == [
               "一叶扁舟缓缓地驶了过来，艄公将一块踏脚板搭上堤岸，以便乘客\n上下。\n"
             ]

      assert Room.has_exit_by_id?("guiyun:taihu", "enter")
      assert Room.has_exit_by_id?("guiyun:duchuan", "out")
      assert exit_target("guiyun:duchuan", "out") == "guiyun:taihu"
      assert Room.get_state_by_id("guiyun:duchuan", "vehicle:guiyun_duchuan") == 1
    end

    test "跑完四步：出口全部回收 + flag 清除（玩家被送达 matou）" do
      cfg = Trigger.config("guiyun:taihu") |> Map.put(:timings, @fast_timings)
      Vehicle.check_trigger(conn("guiyun:taihu"), "guiyun:taihu", cfg)

      Process.sleep(200)

      refute Room.has_exit_by_id?("guiyun:taihu", "enter")
      refute Room.has_exit_by_id?("guiyun:duchuan", "out")
      assert Room.get_state_by_id("guiyun:duchuan", "vehicle:guiyun_duchuan") == nil
    end
  end

  describe "guiyun:taihu 门控" do
    test "载具已停靠（enter 出口存在）→ 广播 already_vision，不启动链路" do
      Room.set_exit("guiyun:taihu", "enter", "guiyun:duchuan")
      cfg = Trigger.config("guiyun:taihu") |> Map.put(:timings, @fast_timings)
      conn = Vehicle.check_trigger(conn("guiyun:taihu"), "guiyun:taihu", cfg)

      assert published(conn) == ["岸边一只渡船上的老艄公说道：正等着你呢，上来吧。\n"]
      refute Room.get_state_by_id("guiyun:duchuan", "vehicle:guiyun_duchuan")
      assert Room.has_exit_by_id?("guiyun:taihu", "enter")
    end

    test "载具在途（trigger_flag 已置）→ 广播 busy_vision，不启动链路" do
      Room.put_state_by_id("guiyun:duchuan", "vehicle:guiyun_duchuan", 1)
      cfg = Trigger.config("guiyun:taihu") |> Map.put(:timings, @fast_timings)
      conn = Vehicle.check_trigger(conn("guiyun:taihu"), "guiyun:taihu", cfg)

      assert published(conn) == ["只听得湖面上隐隐传来：“别急嘛，这儿正忙着呐……”\n"]
      refute Room.has_exit_by_id?("guiyun:taihu", "enter")
      assert Room.get_state_by_id("guiyun:duchuan", "vehicle:guiyun_duchuan") == 1
    end
  end

  # ---- 数据驱动分发（RoomAction → Vehicle.check_trigger） ------------------

  describe "Vehicle.Trigger.run 数据驱动分发" do
    test "up2 触发词经 RoomAction 分发后启动吊篮链路" do
      conn = Trigger.run(conn("heimuya:up2"), %{room_id: "heimuya:up2"})

      assert conn.private.channel_changes != []
      assert Room.has_exit_by_id?("heimuya:up2", "enter")
      assert Room.get_state_by_id("heimuya:basket", "vehicle:heimuya_basket") == 1
    end

    test "未配置的房间 → 原样返回 conn（不启动链路）" do
      conn = Trigger.run(conn("guiyun:taihu"), %{room_id: "somewhere:else"})
      assert conn.private.channel_changes == []
      refute Room.has_exit_by_id?("guiyun:taihu", "enter")
    end
  end

  # ---- helpers --------------------------------------------------------------

  defp conn(room_id, _opts \\ []) do
    character = %Kalevala.Character{
      id: "test-player",
      name: "玩家",
      room_id: room_id,
      attributes: %{"wiz_level" => 0},
      meta: %PlayerMeta{temp: %{}},
      inventory: []
    }

    %Conn{
      character: character,
      private: %Private{channel_changes: []},
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

  defp published(conn) do
    conn.private.channel_changes
    |> Enum.reverse()
    |> Enum.filter(fn
      {:publish, _chan, %{data: %{type: "vision"}}, _opts, _err} -> true
      _ -> false
    end)
    |> Enum.map(fn {:publish, _chan, event, _opts, _err} -> event.data.text end)
  end
end
