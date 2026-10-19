defmodule Kantele.World.ItemActionDispatcherTest do
  use ExUnit.Case, async: true

  alias Kantele.World.ItemAction
  alias Kantele.World.ItemActionDispatcher
  alias Kantele.World.ItemActionHandlers

  # 假 handler：实现 ItemAction 行为，把 verb/trailing/item 记到 conn 上以便断言被调用。
  defmodule FakePlay do
    use ItemAction

    def run(conn, %{verb: verb, trailing: trailing, item: item}) do
      Map.put(conn, :fake_called, {verb, trailing, item.name})
    end
  end

  # LPC `return 0`：本对象不处理（如 `<song> with <id>` 的 id 不匹配）
  defmodule DeclinePlay do
    use ItemAction

    def run(_conn, _params), do: :not_handled
  end

  defp item(name, actions) do
    %Kalevala.World.Item{
      id: "z:#{name}",
      name: name,
      description: "测试物品",
      meta: %{actions: actions}
    }
  end

  defp instance(%Kalevala.World.Item{} = item) do
    %Kalevala.World.Item.Instance{
      id: "instance-#{item.id}",
      item_id: item.id,
      item: item,
      created_at: ~U[2026-01-01 00:00:00Z]
    }
  end

  defp conn(character \\ %Kalevala.Character{}) do
    %{private: %{room: nil}, character: character, output: []}
  end

  defp put_room_id(conn, room_id) do
    Map.put(conn, :character, %Kalevala.Character{conn.character | room_id: room_id})
  end

  # 假注册表：只认 play_qin，其余视为未移植。
  defp fake_lookup do
    fn
      "play_qin" -> {:ok, {FakePlay, :run}}
      "decline" -> {:ok, {DeclinePlay, :run}}
      handler -> {:unimplemented, handler}
    end
  end

  describe "动词提取（经 resolve 间接验证）" do
    test "前导/尾部空白被剥离，只取首词" do
      huqin = item("胡琴", [%{verb: "play", handler: "play_qin"}])
      conn = conn() |> put_room_id("z:r")

      assert {:handled, {FakePlay, :run}, params} =
               ItemActionDispatcher.resolve(conn, "  play   guangling-san  ", fake_lookup(), fn _ ->
                 [instance(huqin)]
               end)

      assert params.verb == "play"
      assert params.trailing == "guangling-san"
    end

    test "全空白 / 空输入 → :not_handled（不会误命中）" do
      huqin = item("胡琴", [%{verb: "play", handler: "play_qin"}])
      conn = conn() |> put_room_id("z:r")
      items_fun = fn _ -> [instance(huqin)] end

      assert :not_handled = ItemActionDispatcher.resolve(conn, "   ", fake_lookup(), items_fun)
      assert :not_handled = ItemActionDispatcher.resolve(conn, "", fake_lookup(), items_fun)
    end
  end

  describe "resolve/4" do
    test "候选物品 actions 含 verb 且 handler 已注册 → {:handled, {mod, fun}, params}" do
      huqin = item("胡琴", [%{verb: "play", handler: "play_qin"}])
      conn = conn() |> put_room_id("z:r")

      assert {:handled, {FakePlay, :run}, params} =
               ItemActionDispatcher.resolve(conn, "play guangling-san", fake_lookup(), fn _ ->
                 [instance(huqin)]
               end)

      assert params.verb == "play"
      assert params.trailing == "guangling-san"
      assert params.room_id == "z:r"
      assert params.item.name == "胡琴"
      assert params.handler == "play_qin"
      assert params.instance.item_id == "z:胡琴"
    end

    test "候选物品无该 verb → :not_handled（即便注册表认得 handler）" do
      book = item("书", [%{verb: "read", handler: "do_read"}])
      conn = conn() |> put_room_id("z:r")

      assert :not_handled =
               ItemActionDispatcher.resolve(conn, "play x", fake_lookup(), fn _ -> [instance(book)] end)
    end

    test "handler 未移植 → :not_handled（首个候选跳过，找下一个已注册候选）" do
      unported = item("面具", [%{verb: "pretend", handler: "do_pretend"}])
      huqin = item("胡琴", [%{verb: "play", handler: "play_qin"}])
      conn = conn() |> put_room_id("z:r")

      assert :not_handled =
               ItemActionDispatcher.resolve(conn, "pretend girl", fake_lookup(), fn _ ->
                 [instance(unported)]
               end)

      assert {:handled, {FakePlay, :run}, _params} =
               ItemActionDispatcher.resolve(conn, "play x", fake_lookup(), fn _ ->
                 [instance(unported), instance(huqin)]
               end)
    end

    test "conn 没有 character → 默认取数返回空 → :not_handled（安全降级，不崩溃）" do
      conn = %{private: %{room: nil}, output: []}

      assert :not_handled = ItemActionDispatcher.resolve(conn, "play x", fake_lookup())
      assert :not_handled = ItemActionDispatcher.dispatch(conn, "play x", fake_lookup())
    end

    test "character 为 nil（引擎未初始化）→ 默认取数不崩 → :not_handled" do
      conn = %{private: %{room: nil}, character: nil, output: []}

      assert :not_handled = ItemActionDispatcher.resolve(conn, "play x", fake_lookup())
    end
  end

  describe "dispatch/4（接线等价）" do
    test "正向路径：handler 被调用，返回 {:handled, conn}" do
      huqin = item("胡琴", [%{verb: "play", handler: "play_qin"}])
      conn = conn() |> put_room_id("z:r")

      assert {:handled, conn2} =
               ItemActionDispatcher.dispatch(conn, "play guangling-san", fake_lookup(), fn _ ->
                 [instance(huqin)]
               end)

      assert conn2.fake_called == {"play", "guangling-san", "胡琴"}
    end

    test "handler 返回 :not_handled（LPC return 0）后继续尝试下一个候选" do
      zheng = item("古筝", [%{verb: "play", handler: "decline"}])
      huqin = item("胡琴", [%{verb: "play", handler: "play_qin"}])
      conn = conn() |> put_room_id("z:r")

      assert {:handled, conn2} =
               ItemActionDispatcher.dispatch(conn, "play x", fake_lookup(), fn _ ->
                 [instance(zheng), instance(huqin)]
               end)

      assert conn2.fake_called == {"play", "x", "胡琴"}
    end

    test "全部候选均 return 0 → :not_handled（放行全局命令）" do
      zheng = item("古筝", [%{verb: "play", handler: "decline"}])
      conn = conn() |> put_room_id("z:r")

      assert :not_handled =
               ItemActionDispatcher.dispatch(conn, "play x", fake_lookup(), fn _ -> [instance(zheng)] end)
    end

    test "无候选（空房间/空背包）→ :not_handled" do
      conn = conn() |> put_room_id("z:r")

      assert :not_handled =
               ItemActionDispatcher.dispatch(conn, "play x", fake_lookup(), fn _ -> [] end)
    end
  end

  describe "候选物品取数（生产路径：背包优先、房间地上次之）" do
    test "private.room 注入 item_instances 时按房间地上取数" do
      huqin = item("胡琴", [%{verb: "play", handler: "play_qin"}])
      room = %Kantele.World.Room{id: "z:r", key: "r", zone_id: "z"}
             |> Map.put(:item_instances, [instance(huqin)])

      conn = %{private: %{room: room}, character: %Kalevala.Character{room_id: "z:r"}, output: []}

      assert {:handled, conn2} = ItemActionDispatcher.dispatch(conn, "play x", fake_lookup())
      assert conn2.fake_called == {"play", "x", "胡琴"}
    end

    test "背包物品优先于房间地上（LPC init() 顺序）" do
      carried = item("铁琴剑", [%{verb: "play", handler: "play_qin"}])
      ground = item("胡琴", [%{verb: "play", handler: "play_qin"}])

      room = %Kantele.World.Room{id: "z:r", key: "r", zone_id: "z"}
             |> Map.put(:item_instances, [instance(ground)])

      conn = %{
        private: %{room: room},
        character: %Kalevala.Character{room_id: "z:r", inventory: [instance(carried)]},
        output: []
      }

      assert {:handled, conn2} = ItemActionDispatcher.dispatch(conn, "play x", fake_lookup())
      assert conn2.fake_called == {"play", "x", "铁琴剑"}
    end

    test "默认 items_fun 查房间进程：未知房间 → :not_handled（安全降级，不崩溃）" do
      conn = %{private: %{room: nil}, character: %Kalevala.Character{room_id: "no:such_room"}, output: []}

      assert :not_handled = ItemActionDispatcher.dispatch(conn, "play x", fake_lookup())
    end

    test "定义缺失的占位物品（meta 为裸 map）不崩，无 actions 自然落空" do
      inst = %Kalevala.World.Item.Instance{
        id: "instance-ghost",
        item_id: "z:ghost",
        created_at: ~U[2026-01-01 00:00:00Z]
      }

      conn = conn(%Kalevala.Character{room_id: "z:r", inventory: [inst]})

      assert :not_handled =
               ItemActionDispatcher.dispatch(conn, "play x", fake_lookup(), fn _ -> [inst] end)
    end
  end

  describe "ItemActionHandlers.lookup/1（真实注册表）" do
    test "play_qin / play_xiao / play_zheng / do_read 已注册" do
      assert {:ok, {Kantele.World.ItemActions.Play, :run}} =
               ItemActionHandlers.lookup("play_qin")

      assert {:ok, {Kantele.World.ItemActions.Play, :run}} =
               ItemActionHandlers.lookup("play_xiao")

      assert {:ok, {Kantele.World.ItemActions.Play, :run}} =
               ItemActionHandlers.lookup("play_zheng")

      assert {:ok, {Kantele.World.ItemActions.Read, :run}} =
               ItemActionHandlers.lookup("do_read")
    end

    test "未移植 handler → {:unimplemented, handler}" do
      assert {:unimplemented, "do_pretend"} = ItemActionHandlers.lookup("do_pretend")
      assert {:unimplemented, ""} = ItemActionHandlers.lookup("")
    end
  end
end
