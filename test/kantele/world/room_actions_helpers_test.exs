defmodule Kantele.World.RoomActions.HelpersTest do
  use ExUnit.Case, async: true

  alias Kalevala.Character
  alias Kalevala.Character.Conn
  alias Kalevala.Character.Conn.Private
  alias Kantele.World.RoomActions.Helpers

  describe "render_to_player/2（LPC write 等价）" do
    test "把文本推入 conn.output（仅本人可见，不广播）" do
      conn = %Conn{output: []}

      conn2 = Helpers.render_to_player(conn, "别在这里喝！\n")

      assert [%Conn.Text{data: "别在这里喝！\n", newline: true}] = conn2.output
      assert conn2.private.channel_changes == []
    end
  end

  describe "broadcast_vision/3（LPC message_vision 等价）" do
    test "向 rooms:<room_id> 广播 type=vision 消息，并把 $N 替换为行动者名字" do
      conn = %Conn{
        character: %Character{name: "张三", room_id: "z:r"},
        private: %Private{channel_changes: []},
        output: []
      }

      conn2 = Helpers.broadcast_vision(conn, "z:r", "$N 拍了拍手。\n")

      assert [{:publish, "rooms:z:r", event, _opts, _err}] = conn2.private.channel_changes
      assert event.topic == Kalevala.Event.Message
      assert event.data.type == "vision"
      assert event.data.channel_name == "rooms:z:r"
      assert event.data.text == "张三 拍了拍手。\n"
    end

    test "无名字时 $N 回退为「某人」（不崩溃）" do
      conn = %Conn{
        character: %Character{room_id: "z:r"},
        private: %Private{channel_changes: []},
        output: []
      }

      conn2 = Helpers.broadcast_vision(conn, "z:r", "$N 笑了笑。")

      assert [{:publish, "rooms:z:r", event, _opts, _err}] = conn2.private.channel_changes
      assert event.data.text == "某人 笑了笑。"
    end
  end
end
