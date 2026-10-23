defmodule Kantele.World.RoomActions.OpenCloseTest.FakeRoom do
  @moduledoc """
  `{:global, {Kalevala.World.Room, room_id}}` 最小替身（同 `DoubleGateTest` /
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
     %{data: %Kantele.World.Room{id: state.data.id, state: %{}}, private: %{characters: [], item_instances: []}}}
  end
end

defmodule Kantele.World.RoomActions.OpenCloseTest do
  @moduledoc """
  P5-4ak：`do_open`/`do_close` 收尾一批（2 个房间）的移植测试。

  - `hangzhou:loveroom`：`open`/`close` 动词，开/关 `down`→`hangzhou:jiulou`
    （单向、无定时关；附带 `temp["plugin"]` 置位 + 江湖通告广播）。
  - `meizhuang:tianjing`：`open` 动词，开 `south`→`meizhuang:gate` 双向门 + 10s
    定时自关（close 走 `close_gate` 定时器）。
  """
  use ExUnit.Case, async: false

  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.World.Room
  alias Kantele.World.RoomActionHandlers
  alias Kantele.World.RoomActions.DynamicExit
  alias Kantele.World.RoomActions.Hangzhou.Loveroom.Open, as: LoveroomOpen
  alias Kantele.World.RoomActions.Hangzhou.Loveroom.Close, as: LoveroomClose
  alias Kantele.World.RoomActions.Meizhuang.Tianjing.Open, as: TianjingOpen
  alias Kantele.World.RoomActions.OpenCloseTest.FakeRoom

  @room_ids ["hangzhou:loveroom", "meizhuang:tianjing", "meizhuang:gate"]

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
      assert RoomActionHandlers.lookup("hangzhou:loveroom", "do_open") ==
               {:ok, {LoveroomOpen, :run}}

      assert RoomActionHandlers.lookup("hangzhou:loveroom", "do_close") ==
               {:ok, {LoveroomClose, :run}}

      assert RoomActionHandlers.lookup("meizhuang:tianjing", "do_open") ==
               {:ok, {TianjingOpen, :run}}
    end
  end

  # ---- hangzhou:loveroom（open/close down） ----

  describe "hangzhou:loveroom（开/关 down 出口）" do
    test "open 错词 → 你要干什么" do
      conn = LoveroomOpen.run(conn("hangzhou:loveroom"), params("hangzhou:loveroom", "wall"))
      assert output(conn) == ["你要干什么？\n"]
      refute DynamicExit.open?("hangzhou:loveroom", "down")
    end

    test "open door → 开 down→hangzhou:jiulou、清 plugin 标记、播江湖通告" do
      conn = LoveroomOpen.run(conn("hangzhou:loveroom"), params("hangzhou:loveroom", "door"))

      assert DynamicExit.open?("hangzhou:loveroom", "down")
      assert exit_target("hangzhou:loveroom", "down") == "hangzhou:jiulou"
      assert published(conn) |> Enum.any?(&(&1 =~ "终于打开门啦"))
      assert Map.get(temp_of(conn), "plugin") == nil
    end

    test "open 可重复（幂等）" do
      LoveroomOpen.run(conn("hangzhou:loveroom"), params("hangzhou:loveroom", "door"))
      conn = LoveroomOpen.run(conn("hangzhou:loveroom"), params("hangzhou:loveroom", "door"))
      assert exit_target("hangzhou:loveroom", "down") == "hangzhou:jiulou"
      assert output(conn) == []
    end

    test "close 错词 → 你要干什么" do
      conn = LoveroomClose.run(conn("hangzhou:loveroom"), params("hangzhou:loveroom", "wall"))
      assert output(conn) == ["你要干什么？\n"]
    end

    test "close door → 删 down 出口、置 plugin 标记、播江湖通告" do
      LoveroomOpen.run(conn("hangzhou:loveroom"), params("hangzhou:loveroom", "door"))
      conn = LoveroomClose.run(conn("hangzhou:loveroom"), params("hangzhou:loveroom", "door"))

      refute DynamicExit.open?("hangzhou:loveroom", "down")
      assert Map.get(temp_of(conn), "plugin") == 1
      assert published(conn) |> Enum.any?(&(&1 =~ "连门都关上啦"))
    end
  end

  # ---- meizhuang:tianjing（双向门 + 10s 自动关） ----

  describe "meizhuang:tianjing（双向门 + 定时关）" do
    test "错词 → 你要开什么" do
      conn = TianjingOpen.run(conn("meizhuang:tianjing"), params("meizhuang:tianjing", "men"))
      assert output(conn) == ["你要开什么？\n"]
      refute DynamicExit.open?("meizhuang:tianjing", "south")
    end

    test "已经开着 → 大门已经是开着了" do
      TianjingOpen.run(conn("meizhuang:tianjing"), params("meizhuang:tianjing", "gate"))
      conn = TianjingOpen.run(conn("meizhuang:tianjing"), params("meizhuang:tianjing", "gate"))
      assert output(conn) == ["大门已经是开着了。\n"]
      assert published(conn) == []
    end

    test "open gate → 开 south↔gate north、两边各播一句、登记 10s 定时器" do
      subscribe_room("meizhuang:tianjing")
      subscribe_room("meizhuang:gate")

      conn = TianjingOpen.run(conn("meizhuang:tianjing"), params("meizhuang:tianjing", "gate"))

      assert DynamicExit.open?("meizhuang:tianjing", "south")
      assert exit_target("meizhuang:tianjing", "south") == "meizhuang:gate"
      assert DynamicExit.open?("meizhuang:gate", "north")
      assert exit_target("meizhuang:gate", "north") == "meizhuang:tianjing"

      assert published(conn) == ["{npc}使劲把大门打了开来。\n"]
      assert_received {:room_message, msg}, 200
      assert msg =~ "里面有人把大门打开了"
      assert {:once, _ref} = Room.get_state_by_id("meizhuang:tianjing", "exit_timer:close_gate")
    end

    test "10 秒后双向自关（close_gate 定时器回调）" do
      TianjingOpen.run(conn("meizhuang:tianjing"), params("meizhuang:tianjing", "gate"))

      :ok =
        DynamicExit.do_close_after(
          [
            {"meizhuang:tianjing", "south", "护院上前把大门关了起来。\n"},
            {"meizhuang:gate", "north", "乒地一声，里面有人把大门关上了。\n"}
          ],
          false
        )

      refute DynamicExit.open?("meizhuang:tianjing", "south")
      refute DynamicExit.open?("meizhuang:gate", "north")
    end
  end

  # ---- helpers --------------------------------------------------------------

  defp params(room_id, arg), do: %{verb: "open", trailing: arg, room_id: room_id}

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

  defp applied(conn), do: conn.private.update_character || conn.character
  defp temp_of(conn), do: applied(conn).meta.temp

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
