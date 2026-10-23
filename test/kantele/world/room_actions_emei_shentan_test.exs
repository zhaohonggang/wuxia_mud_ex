defmodule Kantele.World.RoomActions.EmeiShentanTest.FakeRoom do
  @moduledoc """
  `{:global, {Kalevala.World.Room, room_id}}` 的最小替身（同
  `DynamicExitTest.FakeRoom`）。

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
    # 取消上一个测试遗留的 3 秒自动关门定时器。
    Enum.each(state.data.state || %{}, fn
      {"exit_timer:" <> _key, tref} -> :timer.cancel(tref)
      _other -> :ok
    end)

    {:reply, :ok, %{state | data: %Kantele.World.Room{id: state.data.id, state: %{}}}}
  end
end

defmodule Kantele.World.RoomActions.EmeiShentanTest do
  @moduledoc """
  P5-4ag：峨眉舍身崖下「深潭」三连房（`emei:st0`/`st1`/`st2`）的 `wang`。

  覆盖点：

  - 注册表：三房都挂 `do_wang`。
  - `wang` 播报「极目四望…」。
  - 四个方向各自独立随机，目标只能落在 LPC 表里列出的房间。
  - `st2` 的 north 能通向 `emei:ssyb`（脱困唯一出路），其余房间不行。
  - 3 秒后四向自动消失（`close_out` 的 `if (query(...))` 守卫 → `only_if_open`）。
  - 未登记房间 `:not_handled`。
  """

  use ExUnit.Case, async: false

  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.World.Room
  alias Kantele.World.RoomActionHandlers
  alias Kantele.World.RoomActions.DynamicExit
  alias Kantele.World.RoomActions.Emei.Shentan.Wang
  alias Kantele.World.RoomActions.EmeiShentanTest.FakeRoom

  @room_ids ["emei:st0", "emei:st1", "emei:st2", "emei:ssyb"]
  @dirs ["east", "west", "south", "north"]

  @vision "\n{npc}极目四望，发现还是有出路的，于是求生试探之心大动。\n"

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
    test "三间深潭都挂了 do_wang，且都指向同一模块" do
      for room_id <- ["emei:st0", "emei:st1", "emei:st2"] do
        assert RoomActionHandlers.lookup(room_id, "do_wang") == {:ok, {Wang, :run}}
      end
    end

    test "舍身崖壁没有 do_wang（它只有 bai / climb）" do
      refute RoomActionHandlers.registered?("emei:ssyb", "do_wang")
    end
  end

  # ---- 播报 -----------------------------------------------------------------

  describe "播报" do
    test "wang 播报「极目四望」" do
      conn = Wang.run(conn("emei:st0"), params("emei:st0"))

      assert published(conn) == [@vision]
    end

    test "wang 后面写什么参数都照样执行（LPC do_wang() 不接收参数）" do
      conn = Wang.run(conn("emei:st0"), params("emei:st0", trailing: "乱七八糟"))

      assert published(conn) == [@vision]
    end
  end

  # ---- 出口表 ---------------------------------------------------------------

  describe "出口表" do
    test "四个方向全部出现出口" do
      _conn = Wang.run(conn("emei:st0"), params("emei:st0"))

      for dir <- @dirs do
        assert DynamicExit.open?("emei:st0", dir), "缺少 #{dir} 出口"
      end
    end

    test "st0/st1 的目标只可能是 st1 或 st2" do
      for room_id <- ["emei:st0", "emei:st1"], _round <- 1..20 do
        Wang.run(conn(room_id), params(room_id))

        for dir <- @dirs do
          assert exit_target(room_id, dir) in ["emei:st1", "emei:st2"]
        end
      end
    end

    test "st2 的 north 能通向舍身崖壁（脱困唯一出路）" do
      # 1/4 概率，跑 60 轮基本必然出现；出现不了说明表写错了。
      hit =
        Enum.any?(1..60, fn _round ->
          Wang.run(conn("emei:st2"), params("emei:st2"))
          exit_target("emei:st2", "north") == "emei:ssyb"
        end)

      assert hit, "st2 的 north 60 轮都没出现 emei:ssyb，出口表可能写错"
    end

    test "st2 的其余方向不会通向 ssyb" do
      for _round <- 1..60 do
        Wang.run(conn("emei:st2"), params("emei:st2"))

        for dir <- ["east", "west", "south"] do
          assert exit_target("emei:st2", dir) in ["emei:st1", "emei:st2"]
        end
      end
    end

    test "st0/st1 的 north 不会通向 ssyb（只有 st2 能脱困）" do
      for room_id <- ["emei:st0", "emei:st1"], _round <- 1..40 do
        Wang.run(conn(room_id), params(room_id))
        assert exit_target(room_id, "north") in ["emei:st1", "emei:st2"]
      end
    end

    test "反复 wang 会无条件覆盖出口（LPC 没有「已开」守卫）" do
      # 手工塞一个野出口，再 wang 一次，它必须被覆盖回表里的目标。
      Room.set_exit("emei:st0", "east", "emei:ssyb")
      assert exit_target("emei:st0", "east") == "emei:ssyb"

      Wang.run(conn("emei:st0"), params("emei:st0"))

      assert exit_target("emei:st0", "east") in ["emei:st1", "emei:st2"]
    end
  end

  # ---- 定时关闭 -------------------------------------------------------------

  describe "定时关闭" do
    test "3 秒后四个方向自动消失" do
      # 用 1ms 的等价调用验证 close_out 的语义（真 3 秒太慢，行为由 DynamicExit 单测覆盖）。
      Wang.run(conn("emei:st0"), params("emei:st0"))

      for dir <- @dirs do
        assert DynamicExit.open?("emei:st0", dir)
      end

      :ok =
        DynamicExit.do_close_after(
          Enum.map(@dirs, &{"emei:st0", &1}),
          true
        )

      for dir <- @dirs do
        refute DynamicExit.open?("emei:st0", dir)
      end
    end

    test "wang 会在房间 state 里登记定时器" do
      Wang.run(conn("emei:st0"), params("emei:st0"))

      assert {:once, ref} = Room.get_state_by_id("emei:st0", "exit_timer:close_out")
      assert is_reference(ref)
    end

    test "连续 wang 只保留最后一个定时器" do
      Wang.run(conn("emei:st0"), params("emei:st0"))
      first = Room.get_state_by_id("emei:st0", "exit_timer:close_out")

      Wang.run(conn("emei:st0"), params("emei:st0"))
      second = Room.get_state_by_id("emei:st0", "exit_timer:close_out")

      assert first != second
    end

    test "关闭时不播报（LPC close_out 里没有 message）" do
      subscribe_room("emei:st0")
      Wang.run(conn("emei:st0"), params("emei:st0"))

      # 清掉 wang 自己的 vision，只观察 close_out 的副作用
      flush_room_messages()

      :ok = DynamicExit.do_close_after(Enum.map(@dirs, &{"emei:st0", &1}), true)

      refute_receive {:room_message, _msg}, 100
    end
  end

  # ---- 未登记房间 -----------------------------------------------------------

  describe "未登记房间" do
    test "其它房间调用 → :not_handled" do
      assert Wang.run(conn("emei:ssyb"), params("emei:ssyb")) == :not_handled
    end
  end

  # ---- helpers --------------------------------------------------------------

  defp params(room_id, opts \\ []),
    do: %{verb: "wang", trailing: Keyword.get(opts, :trailing, ""), room_id: room_id}

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

  # `Room` 的 `exits` 是 `%Kalevala.World.Exit{}` 列表（不是 map）。
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

  defp flush_room_messages do
    receive do
      {:room_message, _msg} -> flush_room_messages()
    after
      0 -> :ok
    end
  end
end
