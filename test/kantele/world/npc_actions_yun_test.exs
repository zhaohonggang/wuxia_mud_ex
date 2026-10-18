defmodule Kantele.World.NpcActions.YunTest do
  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn.Text
  alias Kantele.World.NpcActions.Yun

  defp npc(name) do
    %Kalevala.Character{name: name}
  end

  defp conn(room_id, npc) do
    %Kalevala.Character.Conn{
      character: %Kalevala.Character{name: "玩家", room_id: room_id},
      private: %Kalevala.Character.Conn.Private{
        room: %Kantele.World.Room{id: room_id},
        channel_changes: []
      },
      output: []
    }
  end

  describe "run/2（roar 分支：房间广播 vision）" do
    test "殷素素 roar → 向 rooms:tulong:huichang_back 广播 vision 消息，返回 conn" do
      npc = npc("殷素素")
      conn = conn("tulong:huichang_back", npc)

      assert conn2 =
               Yun.run(conn, %{verb: "yun", trailing: "roar", room_id: "tulong:huichang_back", npc: npc})

      assert [{:publish, "rooms:tulong:huichang_back", event, _opts, _err}] =
               conn2.private.channel_changes

      assert event.topic == Kalevala.Event.Message
      assert event.data.type == "vision"
      assert String.contains?(event.data.text, "殷素素喝道")
      assert String.contains?(event.data.text, "贼子，要想行凶么？")
    end

    test "赵一伤 roar → 使用默认文案并广播" do
      npc = npc("赵一伤")
      conn = conn("tulong:jiulou", npc)

      assert conn2 =
               Yun.run(conn, %{verb: "yun", trailing: "roar", room_id: "tulong:jiulou", npc: npc})

      assert [{:publish, "rooms:tulong:jiulou", event, _opts, _err}] =
               conn2.private.channel_changes

      assert event.data.type == "vision"
      assert String.contains?(event.data.text, "赵一伤喝道")
    end
  end

  describe "run/2（非 roar 分支：LPC return 0，放行）" do
    test "空 arg → :not_handled" do
      npc = npc("殷素素")
      conn = conn("tulong:huichang_back", npc)

      assert :not_handled =
               Yun.run(conn, %{verb: "yun", trailing: "", room_id: "tulong:huichang_back", npc: npc})
    end

    test "其它 arg → :not_handled" do
      npc = npc("殷素素")
      conn = conn("tulong:huichang_back", npc)

      assert :not_handled =
               Yun.run(conn, %{verb: "yun", trailing: "foo", room_id: "tulong:huichang_back", npc: npc})
    end
  end

  describe "run/2（防御性）" do
    test "room_id 为 nil → :not_handled（不崩溃）" do
      npc = npc("殷素素")
      conn = conn(nil, npc)

      assert :not_handled =
               Yun.run(conn, %{verb: "yun", trailing: "roar", room_id: nil, npc: npc})
    end
  end
end
