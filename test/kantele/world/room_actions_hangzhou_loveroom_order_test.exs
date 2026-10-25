defmodule Kantele.World.RoomActions.Hangzhou.Loveroom.OrderTest.FakeRoom do
  @moduledoc """
  `{:global, {Kalevala.World.Room, room_id}}` 最小替身（同 BanquetTest）。

  `Room.get_state_by_id/2` / `put_state_by_id/3` 读写的正是房间进程的
  `data.state`，故这里只需一个带 `data: %Room{state: ...}` 的 GenServer。
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

defmodule Kantele.World.RoomActions.Hangzhou.Loveroom.OrderTest do
  @moduledoc """
  P5-9 #9 一次性场景：杭州楼外楼「相约轩」`order`（移植自
  `d/hangzhou/loveroom.c` 的 `do_order`，洞房狂欢，单 20000）。

  分层测试：
  1. **注册表**：`hangzhou:loveroom` 的 `do_order` → `Order`；非本房 / 未知动词 /
     无角色上下文 → `:not_handled`。
  2. **order party**：付 20000、记房 state（11 道菜）、播幽会通告；钱不足拒绝；
     非法类型返回「这儿只承办幽会小宴。」。
  3. **order end**：本人结束 → 清状态 + 播结束语；非本人 →「这里已经被人包租了。」；
     无宴会时 →「这儿只承办幽会小宴。」。
  4. **已包租**：另一人下单 →「这里已经被人包租了。」、状态保留、不扣钱。

  注：`Order.run/2` 以 room_id 精确匹配 `hangzhou:loveroom`，故用真实房号，
  并 `async: false`（同一 `:global` 房名在用例间由 `start_supervised!` 逐次启停）。
  """

  use ExUnit.Case, async: false

  alias Kalevala.Character.Conn
  alias Kalevala.Character.Conn.Private
  alias Kantele.Character.PlayerMeta
  alias Kantele.World.Room
  alias Kantele.World.RoomActions.Hangzhou.Loveroom.Order
  alias Kantele.World.RoomActions.Hangzhou.Loveroom.OrderTest.FakeRoom
  alias Kantele.World.RoomActionHandlers

  @room "hangzhou:loveroom"

  setup do
    start_supervised!({FakeRoom, {@room, []}}, id: :loveroom_room)
    :ok
  end

  # ---- 注册表 ---------------------------------------------------------------

  describe "注册表" do
    test "do_order 指向 Order" do
      assert RoomActionHandlers.lookup(@room, "do_order") ==
               {:ok, {Order, :run}}
    end

    test "非本房 → :not_handled" do
      conn = conn(room_id: "city:furong")

      assert Order.run(conn, %{verb: "do_order", trailing: "party", room_id: "city:furong"}) ==
               :not_handled
    end

    test "未知动词 → :not_handled" do
      assert Order.run(conn(), %{verb: "do_climb", trailing: "", room_id: @room}) ==
               :not_handled
    end

    test "无角色上下文 → :not_handled" do
      assert Order.run(%Conn{}, %{verb: "do_order", trailing: "party", room_id: @room}) ==
               :not_handled
    end
  end

  # ---- order party ----------------------------------------------------------

  describe "order party" do
    test "付 20000、记房 state（11 道菜）、播幽会通告" do
      result = run_order("party", conn(@room, "p1", "张三", 30_000))

      # 30000 - 20000 = 10000
      assert character_of(result).meta.coins == 10_000

      st = state(@room)
      assert st.owner == "p1"
      assert st.type == "party"
      assert length(st.items) == 11

      assert published(result) ==
               ["【江湖通告】张三和某人在杭州楼外楼幽会 !!!!!!\n\n"]
    end

    test "钱不足（< 20000）→ 拒绝、不扣币、不记状态" do
      result = run_order("party", conn(@room, "p1", "张三", 15_000))

      assert output(result) == "你没有足够的钱或零钱不够。\n"
      assert character_of(result).meta.coins == 15_000
      assert state(@room) == nil
    end

    test "非法类型 → 这儿只承办幽会小宴" do
      assert output(run_order("birthday", conn(@room, "p1", "张三", 100_000))) ==
               "这儿只承办幽会小宴。\n"
    end
  end

  # ---- order end ------------------------------------------------------------

  describe "order end" do
    test "本人 end → 清状态、播结束语" do
      _ordered = run_order("party", conn(@room, "p1", "张三", 30_000))

      result = run_order("end", conn(@room, "p1", "张三", 30_000))

      assert state(@room) == nil
      assert published(result) == ["【江湖通告】幽会终于结束了 !!!!!!\n\n"]
    end

    test "非本人 end → 这里已经被人包租了、状态保留" do
      _ordered = run_order("party", conn(@room, "p1", "张三", 30_000))

      result = run_order("end", conn(@room, "p2", "李四", 30_000))

      assert output(result) == "这里已经被人包租了。\n"
      assert state(@room).owner == "p1"
      assert character_of(result).meta.coins == 30_000
    end

    test "无宴会 end → 这儿只承办幽会小宴" do
      assert output(run_order("end", conn(@room, "p1", "张三", 30_000))) ==
               "这儿只承办幽会小宴。\n"
    end
  end

  # ---- 已包租 ---------------------------------------------------------------

  describe "已包租" do
    test "另一人下单 → 拒绝、状态保留、不扣钱" do
      _first = run_order("party", conn(@room, "p1", "张三", 30_000))

      second = run_order("party", conn(@room, "p2", "李四", 40_000))

      assert output(second) == "这里已经被人包租了。\n"
      assert state(@room).owner == "p1"
      assert character_of(second).meta.coins == 40_000
    end
  end

  # ---- helpers --------------------------------------------------------------

  defp run_order(arg, conn) do
    case Order.run(conn, %{verb: "do_order", trailing: arg, room_id: conn.character.room_id}) do
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

  defp conn(opts \\ []) do
    conn(Keyword.get(opts, :room_id, @room),
         Keyword.get(opts, :id, "player:loveroom_test"),
         Keyword.get(opts, :name, "张三"),
         Keyword.get(opts, :coins, 100_000))
  end

  defp character_of(conn), do: conn.private.update_character || conn.character

  defp output(conn), do: Enum.map_join(conn.output, & &1.data)

  defp state(room_id), do: Room.get_state_by_id(room_id, "loveroom")

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
