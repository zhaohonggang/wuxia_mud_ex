defmodule Kantele.World.RoomActions.VisionMoveTest do
  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kalevala.Character.Conn.Private
  alias Kalevala.Character.Conn.Text
  alias Kantele.World.Room
  alias Kantele.World.RoomActionHandlers
  alias Kantele.World.RoomActionDispatcher
  alias Kantele.World.RoomActions.VisionMove

  defp room_with_actions(actions) do
    %Room{id: "z:r", key: "r", zone_id: "z", actions: actions}
  end

  defp conn_in(room_id, verb, handler) do
    %Conn{
      character: %Kalevala.Character{
        id: "c1",
        name: "测试",
        description: "测试角色",
        room_id: room_id
      },
      private: %Private{
        room: room_with_actions(%{verb => handler}),
        channel_changes: []
      },
      output: [],
      events: []
    }
  end

  defp dispatch(conn, text) do
    RoomActionDispatcher.dispatch(conn, text, &RoomActionHandlers.lookup/2)
  end

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

  defp new_room(conn), do: conn.private.update_character.room_id

  describe "entries/0 覆盖度" do
    test "5 个房间 5 个 verb" do
      assert Map.keys(VisionMove.entries()) |> Enum.sort() ==
               [
                 {"emei:hcawest", "jump"},
                 {"emei:xiaoshulin1", "jump"},
                 {"gumu:taiyi1", "jump"},
                 {"gumu:taiyi2", "climb"},
                 {"mingjiao:gudi3", "enter"}
               ]
    end
  end

  describe "mingjiao:gudi3 do_enter（旧房广播 + 位移，无到达文案）" do
    test "enter dong → 广播「沿着洞壁往外爬」并瞬移到 gudi2" do
      conn = conn_in("mingjiao:gudi3", "enter", "do_enter")

      assert {:handled, conn2} = dispatch(conn, "enter dong")

      assert publishes(conn2) == [
               {"rooms:mingjiao:gudi3", "{npc}深吸了一口气，慢慢沿着洞壁往外爬。\n"}
             ]

      assert new_room(conn2) == "mingjiao:gudi2"
    end

    test "参数不符 → 只提示，不移动（LPC `return 1` + write）" do
      conn = conn_in("mingjiao:gudi3", "enter", "do_enter")

      assert {:handled, conn2} = dispatch(conn, "enter window")

      assert texts(conn2) == ["你想干什么呀?\n"]
      assert is_nil(conn2.private.update_character)
      assert publishes(conn2) == []
    end

    test "无参数 → 同样只提示" do
      conn = conn_in("mingjiao:gudi3", "enter", "do_enter")

      assert {:handled, conn2} = dispatch(conn, "enter")

      assert texts(conn2) == ["你想干什么呀?\n"]
    end
  end

  describe "gumu:taiyi1 do_jump（前后各一次广播）" do
    test "jump chi → 旧房广播「往太乙池中跳去」+ 新房广播「跳进了太乙池中来」" do
      conn = conn_in("gumu:taiyi1", "jump", "do_jump")

      assert {:handled, conn2} = dispatch(conn, "jump chi")

      assert publishes(conn2) == [
               {"rooms:gumu:taiyi1", "\n{npc} 往太乙池中跳去。\n"},
               {"rooms:gumu:taiyi2", "\n{npc}跳进了太乙池中来。\n"}
             ]

      assert new_room(conn2) == "gumu:taiyi2"
    end

    test "参数不符 → 提示「你往哪里跳呀」且不移动" do
      conn = conn_in("gumu:taiyi1", "jump", "do_jump")

      assert {:handled, conn2} = dispatch(conn, "jump down")

      assert texts(conn2) == ["你往哪里跳呀? \n"]
      assert is_nil(conn2.private.update_character)
    end
  end

  describe "gumu:taiyi2 do_climb（与 taiyi1 构成双向）" do
    test "climb up → 回到 taiyi1，两段文案都在各自房间" do
      conn = conn_in("gumu:taiyi2", "climb", "do_climb")

      assert {:handled, conn2} = dispatch(conn, "climb up")

      assert publishes(conn2) == [
               {"rooms:gumu:taiyi2", "{npc}在太乙池中往岸上爬了上去。\n"},
               {"rooms:gumu:taiyi1", "{npc}从太乙池中爬了上去。\n"}
             ]

      assert new_room(conn2) == "gumu:taiyi1"
    end

    test "参数不符 → 提示「那个方向没法爬」" do
      conn = conn_in("gumu:taiyi2", "climb", "do_climb")

      assert {:handled, conn2} = dispatch(conn, "climb down")

      assert texts(conn2) == ["那个方向没法爬。\n"]
      assert is_nil(conn2.private.update_character)
    end
  end

  describe "emei:hcawest / emei:xiaoshulin1（参数不符 return 0）" do
    test "hcawest jump chuang → 跳出窗外到小树林" do
      conn = conn_in("emei:hcawest", "jump", "do_jump")

      assert {:handled, conn2} = dispatch(conn, "jump chuang")

      assert publishes(conn2) == [
               {"rooms:emei:hcawest", "{npc}趁人不注意，跳出窗外。\n"},
               {"rooms:emei:xiaoshulin1", "{npc}从华藏庵里跳窗出来。\n"}
             ]

      assert new_room(conn2) == "emei:xiaoshulin1"
    end

    test "xiaoshulin1 jump chuang → 跳回华藏庵（反向）" do
      conn = conn_in("emei:xiaoshulin1", "jump", "do_jump")

      assert {:handled, conn2} = dispatch(conn, "jump chuang")

      assert publishes(conn2) == [
               {"rooms:emei:xiaoshulin1", "{npc}趁人不注意，跳进窗里。\n"},
               {"rooms:emei:hcawest", "{npc}从华藏庵外跳窗进来。\n"}
             ]

      assert new_room(conn2) == "emei:hcawest"
    end

    test "参数不符 → :not_handled（LPC `return 0`，不输出不移动）" do
      conn = conn_in("emei:hcawest", "jump", "do_jump")

      assert :not_handled = dispatch(conn, "jump wall")
      assert :not_handled = dispatch(conn, "jump")
    end
  end

  describe "房间级隔离与未配置降级" do
    test "同一 verb 在两个房间指向不同目标（房间级注册表）" do
      conn_a = conn_in("emei:hcawest", "jump", "do_jump")
      conn_b = conn_in("emei:xiaoshulin1", "jump", "do_jump")

      assert {:handled, a} = dispatch(conn_a, "jump chuang")
      assert {:handled, b} = dispatch(conn_b, "jump chuang")

      assert new_room(a) == "emei:xiaoshulin1"
      assert new_room(b) == "emei:hcawest"
    end

    test "未配置的 {room, verb} → :not_handled（不会误命中别的房间的表项）" do
      conn = conn_in("some:other", "jump", "do_jump")

      assert :not_handled = dispatch(conn, "jump chuang")
    end
  end
end
