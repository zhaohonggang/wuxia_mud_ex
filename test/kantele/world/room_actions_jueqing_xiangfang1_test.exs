defmodule Kantele.World.RoomActions.Jueqing.Xiangfang1Test.FakeRoom do
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
       private: %{characters: Keyword.get(opts, :characters, []), item_instances: []}
     }}
  end
end

defmodule Kantele.World.RoomActions.Jueqing.Xiangfang1Test do
  @moduledoc """
  P5-4aq-B：`d/jueqing/xiangfang1.c` 的 `do_turn` / `do_jump`。

  - do_turn "pen"：房间 state `marks/转` 开/关切换（对应 LPC 房间单例 temp）
  - do_jump "dong"/"hole"：须 `marks/转` 已置，否则「你乱跳什么？」；已开则本房广播
    （排除行动者）+ 行动者私发 + `:timer.apply_after` 排程延时落到 eyutan2
    （跨房向 eyutan1 广播在延时回调里，测试内不触发）

  房间 state 测试沿用 FakeRoom + 唯一房号模式（同 putiyuan/jianzhong）：handler 直接
  以 `Xiangfang1.run/2` 调用并显式传 `room_id`，绕开注册表按房号查找（唯一房号不在
  `@registry` 中）；注册表映射由 `room_action_handlers_test.exs` 覆盖。
  """
  use ExUnit.Case, async: false

  alias Kalevala.Character.Conn
  alias Kalevala.Character.Conn.Private
  alias Kalevala.Character.Conn.Text
  alias Kantele.Character.Combat
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.World.Room
  alias Kantele.World.RoomActions.Jueqing.Xiangfang1
  alias Kantele.World.RoomActions.Jueqing.Xiangfang1Test.FakeRoom

  @room "jueqing:xiangfang1"

  defp meta(overrides) do
    overrides = if is_list(overrides), do: Map.new(overrides), else: overrides

    vitals =
      Map.merge(
        %{qi: 200, jing: 200, neili: 100, max_neili: 100, max_qi: 200, max_jing: 200},
        Map.get(overrides, :vitals, %{})
      )

    combat =
      %{Combat.new() | busy: Map.get(overrides, :busy, 0), enemies: Map.get(overrides, :enemies, [])}

    %PlayerMeta{vitals: vitals, stats: Stats.new(), combat: combat, temp: %{}}
  end

  defp conn_in(room_id, overrides \\ %{}) do
    %Conn{
      character: %Kalevala.Character{
        id: "c1",
        name: "测试",
        description: "测试角色",
        room_id: room_id,
        # 延时 fire_effect 按 pid 下发 trap/effect：给 self() 让 is_pid 守卫通过，
        # 消息落进测试进程邮箱无人读取（无害），避免 nil pid 触发 FunctionClauseError。
        pid: self(),
        meta: meta(overrides)
      },
      private: %Private{
        room: %Room{id: room_id, key: "r", zone_id: "z", actions: %{}},
        channel_changes: []
      },
      output: [],
      events: []
    }
  end

  defp run(conn, verb, arg), do: Xiangfang1.run(conn, %{verb: verb, trailing: arg, room_id: conn.character.room_id})

  defp texts(conn) do
    Enum.flat_map(conn.output, fn
      %Text{data: data} -> [data]
      _ -> []
    end)
  end

  defp publishes(conn) do
    conn.private.channel_changes
    |> Enum.reverse()
    |> Enum.filter(&match?({:publish, _c, _e, _o, _f}, &1))
    |> Enum.map(fn {:publish, channel, event, _opts, _err} -> {channel, event.data.text} end)
  end

  setup do
    room_id = "#{@room}:test#{System.unique_integer([:positive])}"
    start_supervised!({FakeRoom, {room_id, []}})
    %{room_id: room_id}
  end

  describe "do_turn（转花盆开/关暗道）" do
    test "参数非 pen → 提示", %{room_id: room_id} do
      conn = conn_in(room_id)
      conn2 = run(conn, "turn", "foo")
      assert texts(conn2) == ["你要做什么？\n"]
    end

    test "第一次 turn pen → 置 marks/转 + 广播露洞", %{room_id: room_id} do
      conn = conn_in(room_id)
      conn2 = run(conn, "turn", "pen")
      assert Room.get_state_by_id(room_id, "marks/转") == 1
      assert Enum.any?(publishes(conn2), fn {_c, t} -> String.contains?(t, "露出") and String.contains?(t, "洞口") end)
    end

    test "第二次 turn pen → 删 marks/转 + 广播封洞", %{room_id: room_id} do
      conn = conn_in(room_id)
      conn2 = run(conn, "turn", "pen")
      conn3 = run(conn2, "turn", "pen")
      assert Room.get_state_by_id(room_id, "marks/转") == nil
      assert Enum.any?(publishes(conn3), fn {_c, t} -> String.contains?(t, "封住") end)
    end

    test "别名 zhuan pen 同效", %{room_id: room_id} do
      conn = conn_in(room_id)
      _conn2 = run(conn, "zhuan", "pen")
      assert Room.get_state_by_id(room_id, "marks/转") == 1
    end

    test "busy 守卫", %{room_id: room_id} do
      conn = conn_in(room_id, busy: 5)
      conn2 = run(conn, "turn", "pen")
      assert texts(conn2) == ["你现在正忙着呢！\n"]
      assert Room.get_state_by_id(room_id, "marks/转") == nil
    end

    test "fighting 守卫", %{room_id: room_id} do
      conn = conn_in(room_id, enemies: ["x"])
      conn2 = run(conn, "turn", "pen")
      assert texts(conn2) == ["你还是先把你面前这个家伙解决了再说。\n"]
      assert Room.get_state_by_id(room_id, "marks/转") == nil
    end
  end

  describe "do_jump（跳洞须机关已开）" do
    test "参数非 dong/hole → 提示", %{room_id: room_id} do
      conn = conn_in(room_id)
      conn2 = run(conn, "jump", "foo")
      assert texts(conn2) == ["你要做什么？\n"]
    end

    test "机关未开 jump dong → 你乱跳什么？", %{room_id: room_id} do
      conn = conn_in(room_id)
      conn2 = run(conn, "jump", "dong")
      assert texts(conn2) == ["你乱跳什么？"]
      assert Room.get_state_by_id(room_id, "marks/转") == nil
    end

    test "机关已开 jump dong → 本房排除行动者广播 + 行动者私发 + 排程延时（不立即瞬移）", %{room_id: room_id} do
      # 先开机关
      conn0 = conn_in(room_id)
      _ = run(conn0, "turn", "pen")
      # 再跳
      conn = conn_in(room_id)
      conn2 = run(conn, "jump", "dong")

      assert Enum.any?(publishes(conn2), fn {c, t} ->
               c == "rooms:#{room_id}" and String.contains?(t, "跳进床头的洞口")
             end)

      assert Enum.any?(texts(conn2), &String.contains?(&1, "你纵身一跃，进入洞中"))

      # 瞬移在延时回调里，测试内不发生
      assert conn2.character.room_id == room_id
    end

    test "别名 tiao dong 同效（机关已开）", %{room_id: room_id} do
      conn0 = conn_in(room_id)
      _ = run(conn0, "turn", "pen")
      conn = conn_in(room_id)
      conn2 = run(conn, "tiao", "dong")
      assert Enum.any?(texts(conn2), &String.contains?(&1, "你纵身一跃，进入洞中"))
    end

    test "别名 jump hole 同效（机关已开）", %{room_id: room_id} do
      conn0 = conn_in(room_id)
      _ = run(conn0, "turn", "pen")
      conn = conn_in(room_id)
      conn2 = run(conn, "jump", "hole")
      assert Enum.any?(texts(conn2), &String.contains?(&1, "你纵身一跃，进入洞中"))
    end
  end
end
