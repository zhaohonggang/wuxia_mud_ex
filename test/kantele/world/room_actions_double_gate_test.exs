defmodule Kantele.World.RoomActions.DoubleGateTest.FakeRoom do
  @moduledoc """
  `{:global, {Kalevala.World.Room, room_id}}` 的最小替身（同 `DynamicExitTest`）。

  **全模块只注册一次**（`setup_all` 起、`setup` 复位）—— `:global` 的名字注销是
  异步的，按测试反复 stop/start 在高并发全量跑里必然撞 `already started`。
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

  @impl true
  def init({room_id, opts}) do
    {:ok,
     %{
       data: %Kantele.World.Room{id: room_id, state: Keyword.get(opts, :state, %{})},
       private: %{characters: [], item_instances: []}
     }}
  end

  @impl true
  def handle_call(:reset, _from, state) do
    Enum.each(state.data.state || %{}, fn
      {"exit_timer:" <> _key, tref} -> :timer.cancel(tref)
      _other -> :ok
    end)

    {:reply, :ok, %{state | data: %Kantele.World.Room{id: state.data.id, state: %{}}}}
  end
end

defmodule Kantele.World.RoomActions.DoubleGateTest do
  @moduledoc """
  P5-4ag：两处「双向门 + 定时自动关」—— 凌霄内门吊桥（`lingxiao:gate` ↔
  `lingxiao:shanya`）与少林山门殿大门（`shaolin:smdian` ↔ `shaolin:guangchang1`）。

  共同形状：`open` 开两边 + 10 秒后关；`close` 立刻播一句、2 秒后真正关（LPC 用
  同一个 `call_out` 槽位，所以 `close` 会顶掉 `open` 的 10 秒定时器）。
  """

  use ExUnit.Case, async: false

  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.World.Room
  alias Kantele.World.RoomActionHandlers
  alias Kantele.World.RoomActions.DoubleGateTest.FakeRoom
  alias Kantele.World.RoomActions.Lingxiao.Gate
  alias Kantele.World.RoomActions.Shaolin.Smdian

  @room_ids [
    "lingxiao:gate",
    "lingxiao:shanya",
    "shaolin:smdian",
    "shaolin:guangchang1"
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
    test "两房都挂了 do_open / do_close" do
      assert RoomActionHandlers.lookup("lingxiao:gate", "do_open") == {:ok, {Gate.Open, :run}}
      assert RoomActionHandlers.lookup("lingxiao:gate", "do_close") == {:ok, {Gate.Close, :run}}

      assert RoomActionHandlers.lookup("shaolin:smdian", "do_open") == {:ok, {Smdian.Open, :run}}

      assert RoomActionHandlers.lookup("shaolin:smdian", "do_close") ==
               {:ok, {Smdian.Close, :run}}
    end
  end

  # ---- 凌霄内门吊桥 ---------------------------------------------------------

  describe "lingxiao:gate（放吊桥）" do
    test "open bridge → 开 south 出口、回填 shanya 的 north、两边都播报" do
      conn = Gate.Open.run(conn("lingxiao:gate"), params("lingxiao:gate", "bridge"))

      assert published(conn) == ["{npc}让凌霄弟子把吊桥放了下来。\n"]
      assert exit_target("lingxiao:gate", "south") == "lingxiao:shanya"
      assert exit_target("lingxiao:shanya", "north") == "lingxiao:gate"
    end

    test "open south 是 bridge 的别名" do
      Gate.Open.run(conn("lingxiao:gate"), params("lingxiao:gate", "south"))

      assert exit_target("lingxiao:gate", "south") == "lingxiao:shanya"
    end

    test "已经放下 → 吊桥已经放下来了（不再重置出口）" do
      Gate.Open.run(conn("lingxiao:gate"), params("lingxiao:gate", "bridge"))

      conn = Gate.Open.run(conn("lingxiao:gate"), params("lingxiao:gate", "bridge"))

      assert output(conn) == ["吊桥已经放下来了。\n"]
      assert published(conn) == []
    end

    test "参数不是 bridge/south → 你要开什么" do
      conn = Gate.Open.run(conn("lingxiao:gate"), params("lingxiao:gate", "door"))

      assert output(conn) == ["你要开什么？\n"]
      assert exit_target("lingxiao:gate", "south") == nil
    end

    test "空参数 → 你要开什么" do
      conn = Gate.Open.run(conn("lingxiao:gate"), params("lingxiao:gate", ""))

      assert output(conn) == ["你要开什么？\n"]
    end

    test "close bridge → 立刻播「招呼弟子」，2 秒后才真正关" do
      Gate.Open.run(conn("lingxiao:gate"), params("lingxiao:gate", "bridge"))

      conn = Gate.Close.run(conn("lingxiao:gate"), params("lingxiao:gate", "bridge"))

      assert published(conn) == [
               "{npc}朝凌霄弟子招了一下手，几位弟子点了点头，上前将吊桥吊了上去。\n"
             ]

      # 2 秒定时器还没到点，出口仍在
      assert exit_target("lingxiao:gate", "south") == "lingxiao:shanya"
    end

    test "close 会顶掉 open 的 10 秒定时器（同一个 call_out 槽位）" do
      Gate.Open.run(conn("lingxiao:gate"), params("lingxiao:gate", "bridge"))
      open_timer = Room.get_state_by_id("lingxiao:gate", "exit_timer:close_bridge")

      Gate.Close.run(conn("lingxiao:gate"), params("lingxiao:gate", "bridge"))
      close_timer = Room.get_state_by_id("lingxiao:gate", "exit_timer:close_bridge")

      assert open_timer != close_timer
    end

    test "关着的桥不能 close → 吊桥已经是关着的了" do
      conn = Gate.Close.run(conn("lingxiao:gate"), params("lingxiao:gate", "bridge"))

      assert output(conn) == ["吊桥已经是关着的了。\n"]
    end

    test "close 的参数不是 bridge/south → 你要关什么" do
      Gate.Open.run(conn("lingxiao:gate"), params("lingxiao:gate", "bridge"))

      conn = Gate.Close.run(conn("lingxiao:gate"), params("lingxiao:gate", "door"))

      assert output(conn) == ["你要关什么？\n"]
    end

    test "close_bridge 回调两边各播一句、两个方向都清掉" do
      Gate.Open.run(conn("lingxiao:gate"), params("lingxiao:gate", "bridge"))

      :ok =
        Kantele.World.RoomActions.DynamicExit.do_close_after(
          [
            {"lingxiao:gate", "south", "几位凌霄弟子上前把吊桥关了起来。\n"},
            {"lingxiao:shanya", "north", "只听“嘎嘎嘎嘎”几声，吊桥又被关了起来。\n"}
          ],
          false
        )

      assert exit_target("lingxiao:gate", "south") == nil
      assert exit_target("lingxiao:shanya", "north") == nil
    end
  end

  # ---- 少林山门殿 -----------------------------------------------------------

  describe "shaolin:smdian（开山门）" do
    test "open gate → 开 south 出口、回填 guangchang1 的 north" do
      conn = Smdian.Open.run(conn("shaolin:smdian"), params("shaolin:smdian", "gate"))

      assert published(conn) == ["{npc}使劲把大门打了开来。\n"]
      assert exit_target("shaolin:smdian", "south") == "shaolin:guangchang1"
      assert exit_target("shaolin:guangchang1", "north") == "shaolin:smdian"
    end

    test "open south 是 gate 的别名" do
      Smdian.Open.run(conn("shaolin:smdian"), params("shaolin:smdian", "south"))

      assert exit_target("shaolin:smdian", "south") == "shaolin:guangchang1"
    end

    test "已经开着 → 大门已经是开着了" do
      Smdian.Open.run(conn("shaolin:smdian"), params("shaolin:smdian", "gate"))

      conn = Smdian.Open.run(conn("shaolin:smdian"), params("shaolin:smdian", "gate"))

      assert output(conn) == ["大门已经是开着了。\n"]
      assert published(conn) == []
    end

    test "参数不是 gate/south → 你要开什么" do
      conn = Smdian.Open.run(conn("shaolin:smdian"), params("shaolin:smdian", "men"))

      assert output(conn) == ["你要开什么？\n"]
    end

    test "close gate → 立刻播「朝僧兵点头」，2 秒后才真正关" do
      Smdian.Open.run(conn("shaolin:smdian"), params("shaolin:smdian", "gate"))

      conn = Smdian.Close.run(conn("shaolin:smdian"), params("shaolin:smdian", "gate"))

      assert published(conn) == ["{npc}朝着僧兵点了点头。\n"]
      assert exit_target("shaolin:smdian", "south") == "shaolin:guangchang1"
    end

    test "关着的大门不能 close → 大门已经是关着的了" do
      conn = Smdian.Close.run(conn("shaolin:smdian"), params("shaolin:smdian", "gate"))

      assert output(conn) == ["大门已经是关着的了。\n"]
    end

    test "close 的参数不是 gate/south → 你要关什么" do
      Smdian.Open.run(conn("shaolin:smdian"), params("shaolin:smdian", "gate"))

      conn = Smdian.Close.run(conn("shaolin:smdian"), params("shaolin:smdian", "men"))

      assert output(conn) == ["你要关什么？\n"]
    end

    test "close_gate 回调两边各播一句、两个方向都清掉" do
      Smdian.Open.run(conn("shaolin:smdian"), params("shaolin:smdian", "gate"))

      :ok =
        Kantele.World.RoomActions.DynamicExit.do_close_after(
          [
            {"shaolin:smdian", "south", "僧兵上前把大门关了起来。\n"},
            {"shaolin:guangchang1", "north", "只听乒地一声，里面有人把大门关上了。\n"}
          ],
          false
        )

      assert exit_target("shaolin:smdian", "south") == nil
      assert exit_target("shaolin:guangchang1", "north") == nil
    end
  end

  # ---- helpers --------------------------------------------------------------

  defp params(room_id, arg),
    do: %{verb: "open", trailing: arg, room_id: room_id}

  defp conn(room_id, opts \\ []) do
    character = %Kalevala.Character{
      id: Keyword.get(opts, :id, "test-player"),
      name: Keyword.get(opts, :name, "玩家"),
      room_id: room_id,
      attributes: %{"wiz_level" => 0},
      meta: %PlayerMeta{temp: %{}},
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

  defp published(conn) do
    conn.private.channel_changes
    |> Enum.reverse()
    |> Enum.filter(fn
      {:publish, _chan, %{data: %{type: "vision"}}, _opts, _err} -> true
      _ -> false
    end)
    |> Enum.map(fn {:publish, _chan, event, _opts, _err} -> event.data.text end)
  end

  defp output(conn), do: Enum.map(conn.output, & &1.data)
end
