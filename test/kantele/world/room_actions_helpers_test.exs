defmodule Kantele.World.RoomActions.HelpersTest.FailingCommunication do
  @moduledoc """
  桩：`publish/3` 恒定失败，用来验证 `broadcast_vision/4` 的错误分支不崩溃（R15）。
  """

  def publish(_channel_name, _event, _options), do: {:error, :boom}
  def subscribe(_channel_name, _options), do: :ok
  def unsubscribe(_channel_name, _options), do: :ok
end

defmodule Kantele.World.RoomActions.HelpersTest do
  use ExUnit.Case, async: true

  alias Kalevala.Character
  alias Kalevala.Character.Conn
  alias Kalevala.Character.Conn.Private
  alias Kantele.World.RoomActions.Helpers
  alias Kantele.World.RoomActions.HelpersTest.FailingCommunication

  describe "render_to_player/2（LPC write 等价）" do
    test "把文本推入 conn.output（仅本人可见，不广播）" do
      conn = %Conn{output: []}

      conn2 = Helpers.render_to_player(conn, "别在这里喝！\n")

      assert [%Conn.Text{data: "别在这里喝！\n", newline: true}] = conn2.output
      assert conn2.private.channel_changes == []
    end
  end

  describe "broadcast_vision/3（LPC message_vision 等价）" do
    test "向 rooms:<room_id> 广播 type=vision 消息，$N 归一化为 {npc}（不预先替换名字）" do
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
      # {npc} 留给 VisionView 按接收者渲染：行动者→「你」，旁观者→行动者姓名
      assert event.data.text == "{npc} 拍了拍手。\n"
    end

    test "{npc} 经 VisionView 分流：行动者看到「你」，旁观者看到姓名" do
      conn = %Conn{
        character: %Character{name: "张三", room_id: "z:r"},
        private: %Private{channel_changes: []},
        output: []
      }

      conn2 = Helpers.broadcast_vision(conn, "z:r", "$N 拍了拍手。\n")

      assert [{:publish, _c, event, _opts, _err}] = conn2.private.channel_changes

      echo = Kantele.Character.VisionView.render("echo", %{text: event.data.text})
      listen =
        Kantele.Character.VisionView.render("listen", %{
          text: event.data.text,
          character: %Character{name: "张三"}
        })

      assert echo.text == "你 拍了拍手。\n"
      assert listen.text == "张三 拍了拍手。\n"
    end

    test "行动者无名字时，旁观者渲染回退为「某人」（不崩溃）" do
      conn = %Conn{
        character: %Character{room_id: "z:r"},
        private: %Private{channel_changes: []},
        output: []
      }

      conn2 = Helpers.broadcast_vision(conn, "z:r", "$N 笑了笑。")

      assert [{:publish, "rooms:z:r", event, _opts, _err}] = conn2.private.channel_changes
      assert event.data.text == "{npc} 笑了笑。"

      listen =
        Kantele.Character.VisionView.render("listen", %{
          text: event.data.text,
          character: %Character{}
        })

      assert listen.text == "某人 笑了笑。"
    end
  end

  # R15 回归：`broadcast_vision/4` 的错误回调曾写成 `publish_error/1`，
  # 而 `Foreman.Channel` 调的是 `error_fun.(conn, {:error, reason})`（两个参数），
  # 一旦发布失败就会 `UndefinedFunctionError`，把「静默降级」变成「崩溃」。
  describe "broadcast_vision/4 的发布失败降级（R15 回归）" do
    test "error_fun 是 /2，按 Foreman 的调用形状返回原 conn 而不崩溃" do
      conn = %Conn{
        character: %Character{name: "张三", room_id: "z:r"},
        private: %Private{channel_changes: []},
        output: []
      }

      conn2 = Helpers.broadcast_vision(conn, "z:r", "$N 拍了拍手。\n")

      assert [{:publish, _channel, _event, _opts, error_fun}] = conn2.private.channel_changes
      assert is_function(error_fun, 2)

      # 与 `Kalevala.Character.Foreman.Channel` 的调用方式完全一致
      assert error_fun.(conn2, {:error, :not_subscribed}) == conn2
    end

    test "发布失败时 handle_channels/2 不崩溃（端到端走 Foreman）" do
      conn = %Conn{
        character: %Character{name: "张三", room_id: "z:r"},
        private: %Private{channel_changes: []},
        output: []
      }

      conn2 = Helpers.broadcast_vision(conn, "z:r", "$N 拍了拍手。\n")

      state = %{communication_module: FailingCommunication}

      assert %Conn{} = result = Kalevala.Character.Foreman.Channel.handle_channels(conn2, state)
      assert result.output == conn2.output
    end
  end
end
