defmodule Kantele.World.NpcActionDispatcherTest do
  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn.Text
  alias Kantele.World.NpcAction
  alias Kantele.World.NpcActionDispatcher
  alias Kantele.World.NpcActionHandlers

  # 假 handler：实现 NpcAction 行为，把 verb/trailing/npc 记到 conn 上以便断言被调用。
  defmodule FakeYun do
    use NpcAction
    def run(conn, %{verb: verb, trailing: trailing, npc: npc}),
      do: Map.put(conn, :fake_called, {verb, trailing, npc.name})
  end

  defp npc(name, add_actions) do
    %Kalevala.Character{
      name: name,
      room_id: "z:r",
      meta: %{init: %{add_actions: add_actions}}
    }
  end

  defp room_with_npcs(npcs) do
    %Kantele.World.Room{id: "z:r", key: "r", zone_id: "z"}
    |> Map.put(:characters, npcs)
  end

  defp conn_with_room(room) do
    %{private: %{room: room}, output: []}
  end

  defp put_room_id(conn, room_id) do
    Map.put(conn, :character, %Kalevala.Character{room_id: room_id})
  end

  # 假注册表：只认 ("z:r", "yun")，其余视为未移植。
  defp fake_lookup do
    fn
      "z:r", "yun" -> {:ok, {FakeYun, :run}}
      _room_id, _verb -> {:unimplemented, :yun}
    end
  end

  describe "动词提取（经 resolve 间接验证，extract_verb 为私有）" do
    test "前导/尾部空白被剥离，只取首词" do
      conn = conn_with_room(room_with_npcs([npc("殷素素", ["yun"])]))
      conn = put_room_id(conn, "z:r")

      assert {:handled, {FakeYun, :run}, params} =
               NpcActionDispatcher.resolve(conn, "  yun   roar  ", fake_lookup())

      assert params.verb == "yun"
      assert params.trailing == "roar"
    end

    test "全空白 / 空输入 → :not_handled（不会误命中）" do
      conn = conn_with_room(room_with_npcs([npc("殷素素", ["yun"])]))
      conn = put_room_id(conn, "z:r")

      assert :not_handled = NpcActionDispatcher.resolve(conn, "   ", fake_lookup())
      assert :not_handled = NpcActionDispatcher.resolve(conn, "", fake_lookup())
    end
  end

  describe "resolve/3" do
    test "房间有 NPC 且 add_actions 含 verb，handler 已注册 → {:handled, {mod, fun}, params}" do
      conn = conn_with_room(room_with_npcs([npc("殷素素", ["yun"])]))
      conn = put_room_id(conn, "z:r")

      assert {:handled, {FakeYun, :run}, params} =
               NpcActionDispatcher.resolve(conn, "yun roar", fake_lookup())

      assert params.verb == "yun"
      assert params.trailing == "roar"
      assert Map.has_key?(params, :npc)
      assert params.npc.name == "殷素素"
    end

    test "params 透传 room_id" do
      conn = conn_with_room(room_with_npcs([npc("殷素素", ["yun"])]))
      conn = put_room_id(conn, "z:r")

      assert {:handled, _mod_fun, params} =
               NpcActionDispatcher.resolve(conn, "yun", fake_lookup())

      assert params.room_id == "z:r"
    end

    test "房间无该 verb 的 NPC → :not_handled（即便注册表认得 handler）" do
      conn = conn_with_room(room_with_npcs([npc("殷素素", ["exert"])]))
      conn = put_room_id(conn, "z:r")

      assert :not_handled = NpcActionDispatcher.resolve(conn, "yun", fake_lookup())
    end

    test "房间有 verb 但 handler 未移植 → :not_handled（真实空注册表其余房间）" do
      conn = conn_with_room(room_with_npcs([npc("殷素素", ["yun"])]))
      conn = put_room_id(conn, "z:r")

      assert :not_handled =
               NpcActionDispatcher.resolve(conn, "yun", &NpcActionHandlers.lookup/2)
    end

    test "conn 没有房间（private.room 为 nil）→ :not_handled（不崩溃）" do
      conn = %{private: %{room: nil}, output: []}
      conn = put_room_id(conn, "z:r")

      assert :not_handled = NpcActionDispatcher.resolve(conn, "yun", fake_lookup())
    end

    test "private.room 为 nil 且无 character/room_id → :not_handled（安全降级）" do
      conn = %{private: %{room: nil}, output: []}

      assert :not_handled =
               NpcActionDispatcher.resolve(conn, "yun", &NpcActionHandlers.lookup/2)
    end
  end

  describe "dispatch/3（接线等价：应用 handler 或放行全局命令）" do
    test "正向路径：handler 被调用，返回 {:handled, conn}" do
      conn = conn_with_room(room_with_npcs([npc("殷素素", ["yun"])]))
      conn = put_room_id(conn, "z:r")

      assert {:handled, conn2} = NpcActionDispatcher.dispatch(conn, "yun roar", fake_lookup())
      assert conn2.fake_called == {"yun", "roar", "殷素素"}
    end

    test "dormant 路径（真实注册表其余房间）：返回 :not_handled，放行全局命令" do
      conn = conn_with_room(room_with_npcs([npc("殷素素", ["yun"])]))
      conn = put_room_id(conn, "z:r")

      assert :not_handled = NpcActionDispatcher.dispatch(conn, "yun", &NpcActionHandlers.lookup/2)
    end

    test "handler 返回 :not_handled（LPC return 0）：dispatch 亦返回 :not_handled" do
      defmodule SilentYun do
        use NpcAction
        def run(conn, _params), do: :not_handled
      end

      lookup = fn
        "z:r", "yun" -> {:ok, {SilentYun, :run}}
        _room_id, _verb -> {:unimplemented, :yun}
      end

      conn = conn_with_room(room_with_npcs([npc("殷素素", ["yun"])]))
      conn = put_room_id(conn, "z:r")

      assert :not_handled = NpcActionDispatcher.dispatch(conn, "yun", lookup)
    end
  end
end
