defmodule Kantele.World.RoomActions.BanquetTest.FakeRoom do
  @moduledoc """
  `{:global, {Kalevala.World.Room, room_id}}` 最小替身（同 `pig_room_test` / `bet_test`）。

  `Room.get_state_by_id/2` / `put_state_by_id/3` 读写的正是房间进程的
  `state.data.state`，故这里只需一个带 `data: %Room{state: ...}` 的 GenServer。
  """
  use GenServer

  def start_link({room_id, opts}) do
    GenServer.start_link(__MODULE__, {room_id, opts},
      name: {:global, {Kalevala.World.Room, room_id}}
    )
  end

  @impl true
  def init({room_id, opts}) do
    {:ok,
     %{
       data: %Kantele.World.Room{id: room_id, state: Keyword.get(opts, :state, %{})},
       private: %{characters: [], item_instances: []}
     }}
  end
end

defmodule Kantele.World.RoomActions.BanquetTest do
  @moduledoc """
  P5-9 #9 一次性场景：醉仙楼宴厅「承办酒席」（移植自
  `d/city/furong.c` / `meigui.c` / `mudan.c` 的 `do_order` + `do_broadcast`）。

  分层测试：
  1. **注册表**：三厅 `order`/`broadcast` → `Banquet`。
  2. **order 接线**：birthday/marry/player 三档付款（player 忠实保留
     `can_afford(50000)`/`pay_money(40000)` 的 LPC 不一致）、钱不足、非法类型、
     已包租、`order end`（本人/非本人/无宴会）。
  3. **broadcast 接线**：本人再公告 / 非本人拒绝。
  4. **各厅厅名**：meigui / mudan 的公告与结束语文案。

  注：`Banquet.run/2` 以 room_id 精确匹配三厅（`Map.has_key?(@halls, ...)`），
  故本测试用**真实房号**而非唯一后缀，并 `async: false`（同一 `:global` 房名
  在用例间由 `start_supervised!` 逐次启停，顺序执行不冲突）。
  """

  use ExUnit.Case, async: false

  alias Kalevala.Character.Conn
  alias Kalevala.Character.Conn.Private
  alias Kantele.Character.PlayerMeta
  alias Kantele.World.Room
  alias Kantele.World.RoomActions.Banquet
  alias Kantele.World.RoomActions.BanquetTest.FakeRoom
  alias Kantele.World.RoomActionHandlers

  @furong "city:furong"
  @meigui "city:meigui"
  @mudan "city:mudan"

  setup do
    # 默认起芙蓉厅（多数用例用它）；meigui/mudan 用例另起（不同 :global 房名）
    start_supervised!({FakeRoom, {@furong, []}}, id: :furong_room)
    :ok
  end

  # ---- 注册表 ---------------------------------------------------------------

  describe "注册表" do
    test "三厅的 order/broadcast 都指向 Banquet" do
      for room <- [@furong, @meigui, @mudan] do
        assert RoomActionHandlers.lookup(room, "do_order") == {:ok, {Banquet, :run}}
        assert RoomActionHandlers.lookup(room, "do_broadcast") == {:ok, {Banquet, :run}}
      end
    end

    test "非宴厅房 → :not_handled" do
      conn = conn("some:room", "p1", "张三")

      assert Banquet.run(conn, %{verb: "do_order", trailing: "birthday", room_id: "some:room"}) ==
               :not_handled
    end

    test "其它动词 → :not_handled" do
      conn = conn(@furong, "p1", "张三")

      assert Banquet.run(conn, %{verb: "do_something", trailing: "", room_id: @furong}) ==
               :not_handled
    end

    test "无角色上下文 → :not_handled" do
      assert Banquet.run(%Conn{}, %{verb: "do_order", trailing: "birthday", room_id: @furong}) ==
               :not_handled
    end
  end

  # ---- order 接线 -----------------------------------------------------------

  describe "order 接线" do
    test "birthday：付 20000、记房 state（18 道菜）、播寿宴通告" do
      result = run_order("birthday", conn(@furong, "p1", "张三", 30_000))

      # 30000 - 20000 = 10000
      assert character_of(result).meta.coins == 10_000

      st = state(@furong)
      assert st.owner == "p1"
      assert st.type == "birthday"
      assert length(st.items) == 18

      assert published(result) == ["【江湖通告】张三现在在醉仙楼芙蓉厅举行生辰寿宴。\n\n"]
    end

    test "marry：付 30000、记 21 道菜、播订婚通告" do
      result = run_order("marry", conn(@furong, "p1", "张三", 40_000))

      assert character_of(result).meta.coins == 10_000
      assert length(state(@furong).items) == 21
      assert published(result) == ["【江湖通告】张三现在在醉仙楼芙蓉厅举行订婚酒宴。\n\n"]
    end

    test "player：查 50000 付 40000（LPC 不一致忠实保留）、记 32 道菜" do
      result = run_order("player", conn(@furong, "p1", "张三", 50_000))

      # 50000 - 40000 = 10000（查 50000、实付 40000）
      assert character_of(result).meta.coins == 10_000
      assert length(state(@furong).items) == 32
      assert published(result) == ["【江湖通告】张三现在在醉仙楼芙蓉厅宴请各路英雄豪杰。\n\n"]
    end

    test "player：有 45000（< 50000 查额）仍判钱不够（不因实付 40000 而放行）" do
      result = run_order("player", conn(@furong, "p1", "张三", 45_000))

      assert output(result) == "你没有足够的钱或零钱不够。\n"
      assert character_of(result).meta.coins == 45_000
      assert state(@furong) == nil
    end

    test "birthday：钱不足 → 拒绝、不扣币、不记状态" do
      result = run_order("birthday", conn(@furong, "p1", "张三", 15_000))

      assert output(result) == "你没有足够的钱或零钱不够。\n"
      assert character_of(result).meta.coins == 15_000
      assert state(@furong) == nil
    end

    test "非法类型 → 你要定什么酒席" do
      assert output(run_order("foo", conn(@furong, "p1", "张三", 100_000))) ==
               "你要定什么酒席?\n"
    end

    test "已被人包租 → 拒绝（另一人下不同的席）" do
      _first = run_order("birthday", conn(@furong, "p1", "张三", 30_000))

      second = run_order("marry", conn(@furong, "p2", "李四", 40_000))

      assert output(second) == "这里已经被人包租了。\n"
      # 仍是张三的生日宴，李四没扣钱
      assert state(@furong).owner == "p1"
      assert character_of(second).meta.coins == 40_000
    end

    test "order end（本人）→ 清状态、播结束语" do
      _ordered = run_order("birthday", conn(@furong, "p1", "张三", 30_000))

      result = run_order("end", conn(@furong, "p1", "张三", 30_000))

      assert state(@furong) == nil
      assert published(result) == ["【江湖通告】芙蓉厅的宴会结束了。\n\n"]
    end

    test "order end（非本人）→ 这里已经被人包租了、状态保留" do
      _ordered = run_order("birthday", conn(@furong, "p1", "张三", 30_000))

      result = run_order("end", conn(@furong, "p2", "李四", 30_000))

      assert output(result) == "这里已经被人包租了。\n"
      assert state(@furong).owner == "p1"
    end

    test "order end（无宴会）→ 你要定什么酒席" do
      assert output(run_order("end", conn(@furong, "p1", "张三", 30_000))) ==
               "你要定什么酒席?\n"
    end
  end

  # ---- broadcast 接线 -------------------------------------------------------

  describe "broadcast 接线" do
    test "本人再公告 → 重播该席通告" do
      _ordered = run_order("marry", conn(@furong, "p1", "张三", 40_000))

      result = run_broadcast(conn(@furong, "p1", "张三", 40_000))

      assert published(result) == ["【江湖通告】张三现在在醉仙楼芙蓉厅举行订婚酒宴。\n\n"]
    end

    test "非本人广播 → 拒绝" do
      _ordered = run_order("marry", conn(@furong, "p1", "张三", 40_000))

      result = run_broadcast(conn(@furong, "p2", "李四", 40_000))

      assert output(result) == "你不是本宴的主人，无法广播。\n"
      assert published(result) == []
    end
  end

  # ---- 各厅厅名 -------------------------------------------------------------

  describe "各厅厅名" do
    test "玫瑰厅：公告「醉仙楼玫瑰厅」、结束语「玫瑰厅的宴会结束了」" do
      start_supervised!({FakeRoom, {@meigui, []}}, id: :meigui_room)

      result = run_order("birthday", conn(@meigui, "p1", "张三", 30_000))
      assert published(result) == ["【江湖通告】张三现在在醉仙楼玫瑰厅举行生辰寿宴。\n\n"]

      ended = run_order("end", conn(@meigui, "p1", "张三", 30_000))
      assert published(ended) == ["【江湖通告】玫瑰厅的宴会结束了。\n\n"]
    end

    test "牡丹厅：公告「醉仙楼牡丹厅」、结束语「牡丹厅的宴会结束了」" do
      start_supervised!({FakeRoom, {@mudan, []}}, id: :mudan_room)

      result = run_order("marry", conn(@mudan, "p1", "张三", 40_000))
      assert published(result) == ["【江湖通告】张三现在在醉仙楼牡丹厅举行订婚酒宴。\n\n"]

      ended = run_order("end", conn(@mudan, "p1", "张三", 40_000))
      assert published(ended) == ["【江湖通告】牡丹厅的宴会结束了。\n\n"]
    end
  end

  # ---- helpers --------------------------------------------------------------

  defp run_order(arg, conn) do
    case Banquet.run(conn, %{verb: "do_order", trailing: arg, room_id: conn.character.room_id}) do
      {:handled, conn2} -> conn2
      other -> other
    end
  end

  defp run_broadcast(conn) do
    case Banquet.run(conn, %{verb: "do_broadcast", trailing: "", room_id: conn.character.room_id}) do
      {:handled, conn2} -> conn2
      other -> other
    end
  end

  defp conn(room_id, id, name, coins \\ 100_000) do
    %Conn{
      character: %Kalevala.Character{
        id: id,
        name: name,
        room_id: room_id,
        meta: %PlayerMeta{temp: %{}, coins: coins},
        inventory: []
      },
      private: %Private{channel_changes: []},
      output: []
    }
  end

  defp character_of(conn), do: conn.private.update_character || conn.character

  defp output(conn), do: Enum.map_join(conn.output, & &1.data)

  defp state(room_id), do: Room.get_state_by_id(room_id, "banquet")

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
