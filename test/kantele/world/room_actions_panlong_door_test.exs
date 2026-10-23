defmodule Kantele.World.RoomActions.PanlongDoorTest.FakeRoom do
  @moduledoc """
  `{:global, {Kalevala.World.Room, room_id}}` 的最小替身（同 `DoBreakTest.FakeRoom`）。

  全模块只注册一次（`setup_all` 起、`setup` 复位），避免全量跑时 `:global`
  名字注销异步导致的 `already started`。
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

defmodule Kantele.World.RoomActions.PanlongDoorTest do
  @moduledoc """
  P5-4ap 续：盘龙居前庭/走道双向木门（`room:qianting` <-> `room:zoudao`）。

  覆盖点：
  - 注册：两房都挂 `do_push` / `do_close`。
  - 推门开门：前庭/走道任一侧推门，两边出口同步打通，播报文案，登记 10s 自动关门。
  - 已开再推 / 已关再关：提示，不动出口。
  - 关门：关闭两边出口，播报文案，取消自动关门定时器。
  - 自动关门：`do_close_after` 超时后两边出口都消失。
  """

  use ExUnit.Case, async: false

  alias Kalevala.Character.Conn
  alias Kantele.Character.Combat
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.Room
  alias Kantele.World.RoomActionHandlers
  alias Kantele.World.RoomActions.DynamicExit

  alias Kantele.World.RoomActions.Room.Panlong.Qianting.Close, as: QiantingClose
  alias Kantele.World.RoomActions.Room.Panlong.Qianting.Push, as: QiantingPush
  alias Kantele.World.RoomActions.Room.Panlong.Zoudao.Close, as: ZoudaoClose
  alias Kantele.World.RoomActions.Room.Panlong.Zoudao.Push, as: ZoudaoPush
  alias Kantele.World.RoomActions.PanlongDoorTest.FakeRoom

  @self_room "room:qianting"
  @neighbor_room "room:zoudao"
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

  # ---- 注册表 -----------------------------------------------------------

  test "注册表：两房都挂了 do_push / do_close" do
    assert RoomActionHandlers.registered?(@self_room, "do_push")
    assert RoomActionHandlers.registered?(@self_room, "do_close")
    assert RoomActionHandlers.registered?(@neighbor_room, "do_push")
    assert RoomActionHandlers.registered?(@neighbor_room, "do_close")
  end

  # ---- 前庭 push / close -------------------------------------------------

  describe "前庭" do
    test "push 关门状态下打开双向出口，并登记自动关门定时器" do
      conn = QiantingPush.run(conn(), params("push"))

      assert DynamicExit.open?(@self_room, @self_dir)
      assert exit_target(@self_room, @self_dir) == @neighbor_room
      assert DynamicExit.open?(@neighbor_room, @neighbor_dir)
      assert exit_target(@neighbor_room, @neighbor_dir) == @self_room

      assert published(conn) |> Enum.any?(&(&1 =~ "推大门"))
      assert {:once, _ref} = Room.get_state_by_id(@self_room, "exit_timer:panlong:gate")
    end

    test "已开再 push 提示，不动出口" do
      QiantingPush.run(conn(), params("push"))
      conn = QiantingPush.run(conn(), params("push"))

      assert output_text(conn) =~ "大门开着呢"
      assert DynamicExit.open?(@self_room, @self_dir)
    end

    test "close 关闭双向出口并取消自动关门定时器" do
      QiantingPush.run(conn(), params("push"))
      assert DynamicExit.open?(@self_room, @self_dir)

      conn = QiantingClose.run(conn(), params("close"))

      refute DynamicExit.open?(@self_room, @self_dir)
      refute DynamicExit.open?(@neighbor_room, @neighbor_dir)
      refute Room.get_state_by_id(@self_room, "exit_timer:panlong:gate")

      assert published(conn) |> Enum.any?(&(&1 =~ "合上大门"))
    end

    test "已关再 close 提示" do
      conn = QiantingClose.run(conn(), params("close"))
      assert output_text(conn) =~ "大门关着呢"
    end
  end

  # ---- 走道 push / close -------------------------------------------------

  describe "走道" do
    test "push 关门状态下打开双向出口（从走道侧发起）" do
      conn = ZoudaoPush.run(conn(@neighbor_room), params("push"))

      assert DynamicExit.open?(@neighbor_room, @neighbor_dir)
      assert exit_target(@neighbor_room, @neighbor_dir) == @self_room
      assert DynamicExit.open?(@self_room, @self_dir)
      assert exit_target(@self_room, @self_dir) == @neighbor_room
    end

    test "close 关闭双向出口（从走道侧发起）" do
      ZoudaoPush.run(conn(@neighbor_room), params("push"))
      assert DynamicExit.open?(@self_room, @self_dir)

      ZoudaoClose.run(conn(@neighbor_room), params("close"))

      refute DynamicExit.open?(@self_room, @self_dir)
      refute DynamicExit.open?(@neighbor_room, @neighbor_dir)
    end
  end

  # ---- 自动关门 ----------------------------------------------------------

  test "自动关门：10s 超时后两边出口都消失" do
    subscribe_room(@self_room)
    subscribe_room(@neighbor_room)

    QiantingPush.run(conn(), params("push"))
    assert DynamicExit.open?(@self_room, @self_dir)

    # 模拟定时器触发（LPC call_out("do_close", 10)）
    DynamicExit.do_close_after(
      [
        {@self_room, @self_dir, nil},
        {@neighbor_room, @neighbor_dir, nil}
      ],
      false
    )

    refute DynamicExit.open?(@self_room, @self_dir)
    refute DynamicExit.open?(@neighbor_room, @neighbor_dir)
  end

  # ---- helpers -----------------------------------------------------------

  defp params(verb, trailing \\ ""), do: %{verb: verb, trailing: trailing, room_id: @self_room}

  defp player(room_id, opts \\ []) do
    vitals = %{Vitals.new() | neili: Keyword.get(opts, :neili, 2000), max_neili: 2000}
    stats = %{Stats.new() | skills: Map.put(Stats.new().skills, "force", 400)}

    %Kalevala.Character{
      id: "test-player",
      name: "玩家",
      room_id: room_id,
      attributes: %{"wiz_level" => 0},
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: Combat.new(),
        damage: %{},
        temp: %{},
        env: %{}
      },
      inventory: []
    }
  end

  defp conn(room_id \\ @self_room, opts \\ []), do: char_conn(player(room_id, opts))

  defp char_conn(character) do
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

  defp output_text(conn) do
    conn.output
    |> Enum.map(fn
      %{data: data} when is_binary(data) -> data
      %Conn.Text{data: data} -> data
      other -> inspect(other)
    end)
    |> Enum.join()
  end

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
