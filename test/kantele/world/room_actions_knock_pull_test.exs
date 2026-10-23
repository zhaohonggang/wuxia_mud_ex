defmodule Kantele.World.RoomActions.KnockPullTest.FakeRoom do
  @moduledoc """
  `{:global, {Kalevala.World.Room, room_id}}` 最小替身（同 `OpenCloseTest` /
  `DoPushTest`）。全模块只注册一次（`setup_all` 起、`setup` 复位）。
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
end

defmodule Kantele.World.RoomActions.KnockPullTest do
  @moduledoc """
  P5-4al：`do_knock` / `do_pull` 开门机关一批（6 个房间）的移植测试。

  共用 `RoomActions.KnockPull` 原语：
  - 5 房为「参数命中即开单向出口 + 定时自关」（少林广场例外为双向）。
  - `meizhuang:gate` 为铜环暗号 4-2-5-3（玩家级 `meta.temp["knock_step"]`）。
  """
  use ExUnit.Case, async: false

  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.World.Room
  alias Kantele.World.RoomActionHandlers
  alias Kantele.World.RoomActions.DynamicExit
  alias Kantele.World.RoomActions.KnockPull
  alias Kantele.World.RoomActions.Meizhuang.Gate.Knock, as: GateKnock
  alias Kantele.World.RoomActions.Quanzhen.Diziju.Pull, as: DizijuPull
  alias Kantele.World.RoomActions.Quanzhen.FuWoshi.Pull, as: FuWoshiPull
  alias Kantele.World.RoomActions.Shaolin.Guangchang1.Knock, as: Guangchang1Knock
  alias Kantele.World.RoomActions.Wanjiegu.Grassland.Knock, as: GrasslandKnock
  alias Kantele.World.RoomActions.Wanjiegu.TreeHole.Pull, as: TreeHolePull
  alias Kantele.World.RoomActions.KnockPullTest.FakeRoom

  @room_ids [
    "shaolin:guangchang1",
    "shaolin:smdian",
    "wanjiegu:grassland",
    "quanzhen:diziju",
    "quanzhen:fu_woshi",
    "wanjiegu:tree_hole",
    "meizhuang:gate",
    "meizhuang:tianjing"
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
    test "六房都挂了 do_knock / do_pull" do
      assert RoomActionHandlers.lookup("shaolin:guangchang1", "do_knock") ==
               {:ok, {Guangchang1Knock, :run}}

      assert RoomActionHandlers.lookup("wanjiegu:grassland", "do_knock") ==
               {:ok, {GrasslandKnock, :run}}

      assert RoomActionHandlers.lookup("meizhuang:gate", "do_knock") ==
               {:ok, {GateKnock, :run}}

      assert RoomActionHandlers.lookup("quanzhen:diziju", "do_pull") ==
               {:ok, {DizijuPull, :run}}

      assert RoomActionHandlers.lookup("quanzhen:fu_woshi", "do_pull") ==
               {:ok, {FuWoshiPull, :run}}

      assert RoomActionHandlers.lookup("wanjiegu:tree_hole", "do_pull") ==
               {:ok, {TreeHolePull, :run}}
    end
  end

  # ---- shaolin:guangchang1（敲 gate 开 north↔smdian 双向门） ----

  describe "shaolin:guangchang1（敲 gate 开 north↔smdian）" do
    test "错词 → 你要敲什么" do
      conn = Guangchang1Knock.run(conn("shaolin:guangchang1"), params("shaolin:guangchang1", "wall"))
      assert output(conn) == ["你要敲什么？\n"]
      refute DynamicExit.open?("shaolin:guangchang1", "north")
    end

    test "已经开着 → 大门已经是开着了" do
      Guangchang1Knock.run(conn("shaolin:guangchang1"), params("shaolin:guangchang1", "gate"))
      conn = Guangchang1Knock.run(conn("shaolin:guangchang1"), params("shaolin:guangchang1", "gate"))
      assert output(conn) == ["大门已经是开着了。\n"]
      assert published(conn) == []
    end

    test "knock gate → 双向开门 + 两边广播 + 10s 定时器" do
      subscribe_room("shaolin:guangchang1")
      subscribe_room("shaolin:smdian")

      conn = Guangchang1Knock.run(conn("shaolin:guangchang1"), params("shaolin:guangchang1", "gate"))

      assert DynamicExit.open?("shaolin:guangchang1", "north")
      assert exit_target("shaolin:guangchang1", "north") == "shaolin:smdian"
      assert DynamicExit.open?("shaolin:smdian", "south")
      assert exit_target("shaolin:smdian", "south") == "shaolin:guangchang1"

      assert published(conn) == ["{npc}轻轻地敲了敲门，只听吱地一声，衣位壮年僧人应声打开大门。\n"]
      assert_received {:room_message, msg}, 200
      assert msg =~ "壮年僧人应声上前把大门开"
      assert {:once, _ref} =
               Room.get_state_by_id("shaolin:guangchang1", "exit_timer:knockpull:shaolin:guangchang1")
    end

    test "10 秒后双向自关（close_gate 回调）" do
      Guangchang1Knock.run(conn("shaolin:guangchang1"), params("shaolin:guangchang1", "gate"))

      :ok =
        DynamicExit.do_close_after(
          [
            {"shaolin:guangchang1", "north", "只听乒地一声，里面有人把大门关上了。\n"},
            {"shaolin:smdian", "south", "壮年僧人上前把大门关了起来。\n"}
          ],
          false
        )

      refute DynamicExit.open?("shaolin:guangchang1", "north")
      refute DynamicExit.open?("shaolin:smdian", "south")
    end
  end

  # ---- wanjiegu:grassland（敲 段 开 north→xiaoting 单向） ----

  describe "wanjiegu:grassland（敲 段 开 north→xiaoting）" do
    test "错词 → 你要敲什么" do
      conn = GrasslandKnock.run(conn("wanjiegu:grassland"), params("wanjiegu:grassland", "foo"))
      assert output(conn) == ["你要敲什么？\n"]
      refute DynamicExit.open?("wanjiegu:grassland", "north")
    end

    test "knock 段 → 开 north→xiaoting + 10s 自关定时器" do
      conn = GrasslandKnock.run(conn("wanjiegu:grassland"), params("wanjiegu:grassland", "段"))

      assert DynamicExit.open?("wanjiegu:grassland", "north")
      assert exit_target("wanjiegu:grassland", "north") == "wanjiegu:xiaoting"
      assert published(conn) |> Enum.any?(&(&1 =~ "将门打开了"))
      assert {:once, _ref} =
               Room.get_state_by_id("wanjiegu:grassland", "exit_timer:knockpull:wanjiegu:grassland")
    end

    test "10 秒后自关" do
      GrasslandKnock.run(conn("wanjiegu:grassland"), params("wanjiegu:grassland", "duan"))
      :ok = DynamicExit.do_close_after([{"wanjiegu:grassland", "north", "门被人关上了。\n"}], false)
      refute DynamicExit.open?("wanjiegu:grassland", "north")
    end
  end

  # ---- quanzhen:diziju（拉 cabinet 开 down→mishi 单向） ----

  describe "quanzhen:diziju（拉 cabinet 开 down→mishi）" do
    test "错词 → 你要拉开什么" do
      conn = DizijuPull.run(conn("quanzhen:diziju"), params("quanzhen:diziju", "foo"))
      assert output(conn) == ["你要拉开什么？\n"]
      refute DynamicExit.open?("quanzhen:diziju", "down")
    end

    test "pull cabinet → 开 down→mishi + 8s 自关定时器" do
      _conn = DizijuPull.run(conn("quanzhen:diziju"), params("quanzhen:diziju", "cabinet"))

      assert DynamicExit.open?("quanzhen:diziju", "down")
      assert exit_target("quanzhen:diziju", "down") == "quanzhen:mishi"
      assert {:once, _ref} =
               Room.get_state_by_id("quanzhen:diziju", "exit_timer:knockpull:quanzhen:diziju")
    end

    test "8 秒后自关" do
      DizijuPull.run(conn("quanzhen:diziju"), params("quanzhen:diziju", "cabinet"))

      :ok =
        DynamicExit.do_close_after(
          [{"quanzhen:diziju", "down", "柜子又吱吱地回到原地，把入口挡住了。\n"}],
          false
        )

      refute DynamicExit.open?("quanzhen:diziju", "down")
    end
  end

  # ---- quanzhen:fu_woshi（拉 drawer 开 down→fu-midao 单向） ----

  describe "quanzhen:fu_woshi（拉 drawer 开 down→fu-midao）" do
    test "错词 → 你要拉开什么" do
      conn = FuWoshiPull.run(conn("quanzhen:fu_woshi"), params("quanzhen:fu_woshi", "foo"))
      assert output(conn) == ["你要拉开什么？\n"]
      refute DynamicExit.open?("quanzhen:fu_woshi", "down")
    end

    test "pull drawer → 开 down→fu-midao + 5s 自关定时器" do
      _conn = FuWoshiPull.run(conn("quanzhen:fu_woshi"), params("quanzhen:fu_woshi", "drawer"))

      assert DynamicExit.open?("quanzhen:fu_woshi", "down")
      assert exit_target("quanzhen:fu_woshi", "down") == "quanzhen:fu-midao"
      assert {:once, _ref} =
               Room.get_state_by_id("quanzhen:fu_woshi", "exit_timer:knockpull:quanzhen:fu_woshi")
    end

    test "5 秒后自关" do
      FuWoshiPull.run(conn("quanzhen:fu_woshi"), params("quanzhen:fu_woshi", "drawer"))

      :ok =
        DynamicExit.do_close_after([{"quanzhen:fu_woshi", "down", "床板又合了起来，把洞口封住了。\n"}], false)

      refute DynamicExit.open?("quanzhen:fu_woshi", "down")
    end
  end

  # ---- wanjiegu:tree_hole（拉 大铁环 开 enter→tunnel1 单向） ----

  describe "wanjiegu:tree_hole（拉 大铁环 开 enter→tunnel1）" do
    test "错词 → 你要拉什么" do
      conn = TreeHolePull.run(conn("wanjiegu:tree_hole"), params("wanjiegu:tree_hole", "foo"))
      assert output(conn) == ["你要拉什么？\n"]
      refute DynamicExit.open?("wanjiegu:tree_hole", "enter")
    end

    test "pull 大铁环 → 开 enter→tunnel1 + 10s 自关定时器" do
      _conn = TreeHolePull.run(conn("wanjiegu:tree_hole"), params("wanjiegu:tree_hole", "大铁环"))

      assert DynamicExit.open?("wanjiegu:tree_hole", "enter")
      assert exit_target("wanjiegu:tree_hole", "enter") == "wanjiegu:tunnel1"
      assert {:once, _ref} =
               Room.get_state_by_id("wanjiegu:tree_hole", "exit_timer:knockpull:wanjiegu:tree_hole")
    end

    test "10 秒后自关" do
      TreeHolePull.run(conn("wanjiegu:tree_hole"), params("wanjiegu:tree_hole", "ring"))

      :ok =
        DynamicExit.do_close_after([{"wanjiegu:tree_hole", "enter", "木板晃了晃，将下面的洞口盖住了。\n"}], false)

      refute DynamicExit.open?("wanjiegu:tree_hole", "enter")
    end
  end

  # ---- meizhuang:gate（铜环暗号 4-2-5-3） ----

  describe "meizhuang:gate（铜环暗号 4-2-5-3）" do
    test "错序清零：4→5（跳过 2）归零、不开门" do
      conn = GateKnock.run(conn("meizhuang:gate"), params("meizhuang:gate", "4"))
      assert KnockPull.get_temp(conn, "knock_step", 0) == 1

      conn = GateKnock.run(conn, params("meizhuang:gate", "5"))
      assert KnockPull.get_temp(conn, "knock_step", 0) == 0
      refute DynamicExit.open?("meizhuang:gate", "north")
    end

    test "非暗号敲击不改进度" do
      conn = GateKnock.run(conn("meizhuang:gate"), params("meizhuang:gate", "4"))
      conn = GateKnock.run(conn, params("meizhuang:gate", "9"))
      assert KnockPull.get_temp(conn, "knock_step", 0) == 1
    end

    test "正确序列 4-2-5-3 → 开 north↔tianjing 双向门 + 10s 定时器" do
      subscribe_room("meizhuang:gate")
      subscribe_room("meizhuang:tianjing")

      run_seq(conn("meizhuang:gate"), ["4", "2", "5", "3"])

      assert DynamicExit.open?("meizhuang:gate", "north")
      assert exit_target("meizhuang:gate", "north") == "meizhuang:tianjing"
      assert DynamicExit.open?("meizhuang:tianjing", "south")
      assert exit_target("meizhuang:tianjing", "south") == "meizhuang:gate"

      assert_received {:room_message, msg}, 200
      assert msg =~ "大门给打开了"
      assert {:once, _ref} =
               Room.get_state_by_id("meizhuang:gate", "exit_timer:gate_close_passage")
    end

    test "已经开着 → 门已经是开着的（敲击被拦）" do
      run_seq(conn("meizhuang:gate"), ["4", "2", "5", "3"])
      conn = GateKnock.run(conn("meizhuang:gate"), params("meizhuang:gate", "4"))
      assert output(conn) == ["门已经是开着的，不用再费力去敲了！\n"]
    end

    test "10 秒后双向自关（close_passage 回调）" do
      run_seq(conn("meizhuang:gate"), ["4", "2", "5", "3"])

      :ok =
        DynamicExit.do_close_after(
          [
            {"meizhuang:gate", "north", "只听“嘎嘎嘎”几声，梅庄内的护院将大门轻轻关上了。\n"},
            {"meizhuang:tianjing", "south", "大门被护院轻轻关上了。\n"}
          ],
          false
        )

      refute DynamicExit.open?("meizhuang:gate", "north")
      refute DynamicExit.open?("meizhuang:tianjing", "south")
    end
  end

  # ---- helpers --------------------------------------------------------------

  defp run_seq(conn, args) do
    Enum.reduce(args, conn, fn arg, c -> GateKnock.run(c, params("meizhuang:gate", arg)) end)
  end

  defp params(room_id, arg), do: %{verb: "knock", trailing: arg, room_id: room_id}

  defp conn(room_id, opts \\ []) do
    character = %Kalevala.Character{
      id: Keyword.get(opts, :id, "test-player"),
      name: Keyword.get(opts, :name, "玩家"),
      room_id: room_id,
      attributes: %{"wiz_level" => 0},
      meta: %PlayerMeta{temp: Keyword.get(opts, :temp, %{})},
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
