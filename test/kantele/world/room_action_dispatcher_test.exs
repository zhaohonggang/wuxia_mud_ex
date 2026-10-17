defmodule Kantele.World.RoomActionDispatcherTest do
  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn.Text
  alias Kantele.World.Room
  alias Kantele.World.RoomAction
  alias Kantele.World.RoomActionDispatcher
  alias Kantele.World.RoomActionHandlers

  # 假 handler：实现 RoomAction 行为，把 verb/trailing 记到 conn 上以便断言被调用。
  defmodule FakeMove do
    use RoomAction
    def run(conn, %{verb: verb, trailing: trailing}), do: Map.put(conn, :fake_called, {verb, trailing})
  end

  defp room_with_actions(actions) do
    %Room{id: "z:r", key: "r", zone_id: "z", actions: actions}
  end

  defp conn_with_room(room) do
    %{private: %{room: room}, output: []}
  end

  # 假注册表：只认 "do_move"，其余视为未移植（忽略 room_id）。
  defp fake_lookup do
    fn
      _room_id, "do_move" -> {:ok, {FakeMove, :run}}
      _room_id, other -> {:unimplemented, other}
    end
  end

  describe "动词提取（经 resolve 间接验证，extract_verb 为私有）" do
    test "前导/尾部空白被剥离，只取首词" do
      conn = conn_with_room(room_with_actions(%{"move" => "do_move"}))

      assert {:handled, {FakeMove, :run}, params} =
               RoomActionDispatcher.resolve(conn, "  move   foo  bar ", fake_lookup())

      assert params.verb == "move"
      assert params.trailing == "foo  bar"
    end

    test "CJK 动词原样匹配（大小写/分词无关）" do
      conn = conn_with_room(room_with_actions(%{"面壁" => "do_mianbi"}))
      cjk_lookup = fn _room_id, "do_mianbi" -> {:ok, {FakeMove, :run}}; _room_id, _ -> {:unimplemented, "x"} end

      assert {:handled, {FakeMove, :run}, params} =
               RoomActionDispatcher.resolve(conn, "面壁 一下", cjk_lookup)

      assert params.verb == "面壁"
      assert params.trailing == "一下"
    end

    test "全空白 / 空输入 → :not_handled（不会误命中）" do
      conn = conn_with_room(room_with_actions(%{"move" => "do_move"}))

      assert :not_handled = RoomActionDispatcher.resolve(conn, "   ", fake_lookup())
      assert :not_handled = RoomActionDispatcher.resolve(conn, "", fake_lookup())
    end
  end

  describe "resolve/3" do
    test "房间有 verb 且 handler 已注册 → {:handled, {mod, fun}, params}" do
      conn = conn_with_room(room_with_actions(%{"move" => "do_move"}))

      assert {:handled, {FakeMove, :run}, params} =
               RoomActionDispatcher.resolve(conn, "move foo", fake_lookup())

      assert params.verb == "move"
      assert params.trailing == "foo"
      assert Map.has_key?(params, :room_id)
      assert is_nil(params.room_id)
    end

    test "房间无此 verb → :not_handled（即便注册表认得 handler）" do
      conn = conn_with_room(room_with_actions(%{"climb" => "do_climb"}))

      assert :not_handled = RoomActionDispatcher.resolve(conn, "move", fake_lookup())
    end

    test "房间有 verb 但 handler 未移植 → :not_handled（真实空注册表其余房间）" do
      conn = conn_with_room(room_with_actions(%{"move" => "do_move"}))

      assert :not_handled = RoomActionDispatcher.resolve(conn, "move", &RoomActionHandlers.lookup/2)
    end

    test "conn 没有房间（private.room 为 nil）→ :not_handled（不崩溃）" do
      conn = %{private: %{room: nil}, output: []}

      assert :not_handled = RoomActionDispatcher.resolve(conn, "move", fake_lookup())
    end

    test "private.room 为 nil 且无 character/room_id → :not_handled（安全降级）" do
      conn = %{private: %{room: nil}, output: []}

      assert :not_handled =
               RoomActionDispatcher.resolve(conn, "move", &RoomActionHandlers.lookup/2)
    end
  end

  describe "Room.actions_by_id/1（运行时取数，引擎不塞 conn.private.room）" do
    test "房间进程不存在 → 返回 %{}（安全降级）" do
      assert Room.actions_by_id("nonexistent:room") == %{}
    end

    test "非字符串 room_id → %{}" do
      assert Room.actions_by_id(nil) == %{}
      assert Room.actions_by_id(123) == %{}
    end
  end

  describe "dispatch/3（接线等价：应用 handler 或放行全局命令）" do
    test "正向路径：handler 被调用，返回 {:handled, conn}" do
      conn = conn_with_room(room_with_actions(%{"move" => "do_move"}))

      assert {:handled, conn2} = RoomActionDispatcher.dispatch(conn, "move foo", fake_lookup())
      assert conn2.fake_called == {"move", "foo"}
    end

    test " dormant 路径（真实注册表其余房间）：返回 :not_handled，放行全局命令" do
      conn = conn_with_room(room_with_actions(%{"move" => "do_move"}))

      assert :not_handled = RoomActionDispatcher.dispatch(conn, "move", &RoomActionHandlers.lookup/2)
    end

    test "房间无 verb：返回 :not_handled" do
      conn = conn_with_room(room_with_actions(%{}))

      assert :not_handled = RoomActionDispatcher.dispatch(conn, "wave", fake_lookup())
    end
  end

  describe "E2E：真实 handler 端到端触发（P5-1b-3 样板）" do
    test "huashan:lianhua 的 tiao → 真实 Tiao handler 被调用并向玩家输出文本" do
      # 注入房间结构体（测试快速路径，等价于运行期 Room.actions_by_id 返回的 data）
      room = room_with_actions(%{"tiao" => "do_tiao"})
      conn = %{private: %{room: room}, character: %{room_id: "huashan:lianhua"}, output: []}

      assert {:handled, conn2} = RoomActionDispatcher.dispatch(conn, "tiao", &RoomActionHandlers.lookup/2)

      texts =
        Enum.flat_map(conn2.output, fn
          %Text{data: data} -> [data]
          _ -> []
        end)

      assert Enum.any?(texts, &String.contains?(&1, "剑冢"))
    end

    test "同名 handler 按房间区分：未注册房间的 do_move → 不触发" do
      room = room_with_actions(%{"move" => "do_move"})
      conn = %{private: %{room: room}, character: %{room_id: "some:other"}, output: []}

      assert :not_handled = RoomActionDispatcher.dispatch(conn, "move", &RoomActionHandlers.lookup/2)
    end

    test "emei:shierpan3 的 clap → 真实 Clap handler 向房间频道广播 vision 消息" do
      # 用真实 Conn/Character/Private 结构体，才能走通 publish_message（房间广播）。
      room = room_with_actions(%{"clap" => "do_clap"})

      conn = %Kalevala.Character.Conn{
        character: %Kalevala.Character{name: "测试", room_id: "emei:shierpan3"},
        private: %Kalevala.Character.Conn.Private{room: room, channel_changes: []},
        output: []
      }

      assert {:handled, conn2} =
               RoomActionDispatcher.dispatch(conn, "clap", &RoomActionHandlers.lookup/2)

      assert [{:publish, "rooms:emei:shierpan3", event, _opts, _err}] = conn2.private.channel_changes
      assert event.topic == Kalevala.Event.Message
      assert event.data.type == "vision"
      assert String.contains?(event.data.text, "群蛙")
    end

    test "baituo:neishi 的 move（欧阳世家 + pen）→ 真实 Move handler 广播开洞" do
      room = room_with_actions(%{"move" => "do_move"})

      conn = %Kalevala.Character.Conn{
        character: %Kalevala.Character{
          name: "测试",
          room_id: "baituo:neishi",
          meta: %{family: %{born_family: "欧阳世家"}}
        },
        private: %Kalevala.Character.Conn.Private{room: room, channel_changes: []},
        output: []
      }

      assert {:handled, conn2} =
               RoomActionDispatcher.dispatch(conn, "move pen", &RoomActionHandlers.lookup/2)

      assert [{:publish, "rooms:baituo:neishi", event, _opts, _err} | _] =
               conn2.private.channel_changes

      assert event.data.type == "vision"
      assert String.contains?(event.data.text, "露出一个黑幽幽的洞口")
    end
  end
end
