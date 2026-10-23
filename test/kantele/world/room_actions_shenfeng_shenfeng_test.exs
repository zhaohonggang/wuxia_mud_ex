defmodule Kantele.World.RoomActions.ShenfengShenfengTest.FakeRoom do
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

defmodule Kantele.World.RoomActions.ShenfengShenfengTest do
  @moduledoc """
  P5-4ap：`shenfeng:shenfeng` 的 `move sand` + `push gate` 移植测试。

  覆盖点：
  - 注册：`do_move` / `do_push` 都挂上。
  - 清沙计数（房间 `mark/sand`）：5 层中间文案、第 6 层「干干净净」、
    第 7 次提示已清完；每次 `start_busy(2)`，忙时拒绝。
  - 推门失败三门槛（force < 300 / sand < 5 / neili < 1500）：震落山脚、
    扣 qi 200 后昏厥（qi=0）、内力**不清零**。
  - 边界：force=300 / sand=5 / neili=1500 恰好通过；开 enter↔yongdao1
    双向门、扣 1000 内力、无定时关。
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
  alias Kantele.World.RoomActions.MoveStone

  alias Kantele.World.RoomActions.Shenfeng.Shenfeng.Push
  alias Kantele.World.RoomActions.Shenfeng.Shenfeng.Sand
  alias Kantele.World.RoomActions.ShenfengShenfengTest.FakeRoom

  @self_room "shenfeng:shenfeng"
  @target_room "shenfeng:yongdao1"
  @room_ids [@self_room, @target_room]

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

  test "注册表：shenfeng:shenfeng 挂 do_move / do_push" do
    assert RoomActionHandlers.registered?(@self_room, "do_move")
    assert RoomActionHandlers.registered?(@self_room, "do_push")
  end

  describe "move sand" do
    test "错词只提示" do
      conn = Sand.run(conn(), params("move", "shazi"))
      assert output_text(conn) =~ "你要干什么"
      assert MoveStone.room_temp(@self_room, "mark/sand", 0) == 0
    end

    test "逐层清沙：前 5 层普通文案，第 6 层收尾，第 7 次提示已清完" do
      for _ <- 1..5 do
        conn = Sand.run(conn(), params("move", "sand"))
        assert published(conn) |> Enum.any?(&(&1 =~ "仔细地清除着覆盖在石门周围的沙子"))
      end

      assert MoveStone.room_temp(@self_room, "mark/sand") == 5

      conn = Sand.run(conn(), params("move", "sand"))
      assert published(conn) |> Enum.any?(&(&1 =~ "清除得干干净净"))
      assert MoveStone.room_temp(@self_room, "mark/sand") == 6

      conn = Sand.run(conn(), params("move", "sand"))
      assert output_text(conn) =~ "石门上现在已经没有沙子了"
      assert MoveStone.room_temp(@self_room, "mark/sand") == 6
    end

    test "start_busy(2)：清一层后立刻再清被拒" do
      conn = Sand.run(conn(), params("move", "sand"))
      assert Combat.busy?(applied(conn).meta.combat)

      conn = Sand.run(reconn(conn), params("move", "sand"))
      assert output_text(conn) =~ "你正忙着呢"
      assert MoveStone.room_temp(@self_room, "mark/sand") == 1
    end
  end

  describe "push gate" do
    test "错词只提示，不开门" do
      conn = Push.run(conn(), params("push", "men"))
      assert output_text(conn) =~ "你要推什么"
      refute DynamicExit.open?(@self_room, "enter")
    end

    test "已开则提示，不重复推" do
      set_sand(6)
      DynamicExit.open(conn(), @self_room, "enter", @target_room, "")

      conn = Push.run(conn(), params("push", "gate"))
      assert output_text(conn) =~ "石门已经是开着的了"
    end

    test "force < 300 → 震落山脚、qi=0、内力不清零" do
      set_sand(6)
      conn = Push.run(conn(force: 299, neili: 2000), params("push", "gate"))
      assert_fell(conn, 2000)
    end

    test "sand < 5 → 震落山脚" do
      set_sand(4)
      conn = Push.run(conn(force: 400, neili: 2000), params("push", "gate"))
      assert_fell(conn, 2000)
    end

    test "neili < 1500 → 震落山脚" do
      set_sand(6)
      conn = Push.run(conn(force: 400, neili: 1499), params("push", "gate"))
      assert_fell(conn, 1499)
    end

    test "边界 force=300 / sand=5 / neili=1500 → 双向开门、扣 1000、无定时关" do
      subscribe_room(@target_room)
      set_sand(5)

      conn = Push.run(conn(force: 300, neili: 1500), params("push", "gate"))

      assert DynamicExit.open?(@self_room, "enter")
      assert exit_target(@self_room, "enter") == @target_room
      assert DynamicExit.open?(@target_room, "out")
      assert exit_target(@target_room, "out") == @self_room
      assert neili_of(conn) == 500
      refute Room.get_state_by_id(@self_room, "exit_timer:movestone:#{@self_room}")

      assert published(conn) |> Enum.any?(&(&1 =~ "将石门震到一边"))
      assert_received {:room_message, msg}, 200
      assert msg =~ "移动石门的隆隆"
    end
  end

  defp assert_fell(conn, expected_neili) do
    assert applied(conn).room_id == "shenfeng:shanjiao"
    assert qi_of(conn) == 0
    assert neili_of(conn) == expected_neili
    refute DynamicExit.open?(@self_room, "enter")

    assert output_text(conn) =~ "震得飞了出去"
    assert published(conn) |> Enum.any?(&(&1 =~ "却见玩家身体突然一晃"))
    assert published(conn) |> Enum.any?(&(&1 =~ "从上面的山峰上坠了下来"))
  end

  defp set_sand(count), do: MoveStone.put_room_temp(@self_room, "mark/sand", count)

  defp params(verb, trailing), do: %{verb: verb, trailing: trailing, room_id: @self_room}

  defp conn(opts \\ []) do
    neili = Keyword.get(opts, :neili, 2000)
    max_neili = Keyword.get(opts, :max_neili, 2000)
    force = Keyword.get(opts, :force, 400)

    vitals = %{Vitals.new() | neili: neili, max_neili: max_neili}
    stats = %{Stats.new() | skills: Map.put(Stats.new().skills, "force", force)}

    %Kalevala.Character{
      id: "test-player",
      name: "玩家",
      room_id: @self_room,
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
    |> char_conn()
  end

  defp char_conn(character) do
    %Conn{
      character: character,
      private: %Conn.Private{channel_changes: []},
      output: []
    }
  end

  defp reconn(conn), do: char_conn(applied(conn))

  defp applied(conn), do: conn.private.update_character || conn.character

  defp neili_of(conn), do: applied(conn).meta.vitals.neili
  defp qi_of(conn), do: applied(conn).meta.vitals.qi

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
