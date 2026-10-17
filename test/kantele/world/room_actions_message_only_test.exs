defmodule Kantele.World.RoomActions.MessageOnlyTest do
  use ExUnit.Case, async: true

  alias Kalevala.Character
  alias Kalevala.Character.Conn
  alias Kalevala.Character.Conn.Private
  alias Kantele.World.RoomActions.MessageOnly

  defp conn_for(room_id, name \\ "测试") do
    %Conn{
      character: %Character{name: name, room_id: room_id},
      private: %Private{channel_changes: []},
      output: []
    }
  end

  defp published_text(conn) do
    case conn.private.channel_changes do
      [{:publish, _chan, event, _opts, _err} | _] -> event.data.text
      _ -> nil
    end
  end

  describe "run/2（数据驱动纯消息）" do
    test "knock：message_vision 广播，$N 归一化为 {npc}（由 VisionView 按接收者渲染）" do
      conn = conn_for("hangzhou:liuzhuang", "李四")

      conn2 = MessageOnly.run(conn, %{verb: "knock", trailing: "", room_id: "hangzhou:liuzhuang"})

      text = published_text(conn2)
      assert is_binary(text)
      # 不预替换名字：行动者经 VisionView echo 渲染成「你」，旁观者渲染成姓名
      assert String.contains?(text, "{npc}")
      refute String.contains?(text, "李四")
      assert String.contains?(text, "敲着门")
    end

    test "reach mutong：按 arg 分支广播木桶文案" do
      conn = conn_for("huanggong:inwell")

      conn2 =
        MessageOnly.run(conn, %{verb: "reach", trailing: "mutong", room_id: "huanggong:inwell"})

      assert String.contains?(published_text(conn2), "木桶")
    end

    test "reach string：按 arg 分支广播长绳文案" do
      conn = conn_for("huanggong:inwell")

      conn2 =
        MessageOnly.run(conn, %{verb: "reach", trailing: "string", room_id: "huanggong:inwell"})

      assert String.contains?(published_text(conn2), "长绳")
    end

    test "reach 未知 arg：不广播（channel_changes 为空）" do
      conn = conn_for("huanggong:inwell")

      conn2 =
        MessageOnly.run(conn, %{verb: "reach", trailing: "whatever", room_id: "huanggong:inwell"})

      assert conn2.private.channel_changes == []
    end

    test "未配置的 {room, verb}：原样返回 conn（不崩溃、不输出）" do
      conn = conn_for("nowhere:room")

      conn2 = MessageOnly.run(conn, %{verb: "dance", trailing: "", room_id: "nowhere:room"})

      assert conn2.private.channel_changes == []
      assert conn2.output == []
    end

    test "chengdu:guangchang drink：房间动作覆盖全局 drink，只给本人「别在这里喝！」" do
      conn = conn_for("chengdu:guangchang")

      conn2 = MessageOnly.run(conn, %{verb: "drink", trailing: "", room_id: "chengdu:guangchang"})

      assert [%Conn.Text{data: "别在这里喝！\n"}] = conn2.output
      assert conn2.private.channel_changes == []
    end

    test "register:prison drop：房间动作覆盖全局 drop，只给本人「这里不能乱仍东西！」" do
      conn = conn_for("register:prison")

      conn2 = MessageOnly.run(conn, %{verb: "drop", trailing: "sword", room_id: "register:prison"})

      assert [%Conn.Text{data: "这里不能乱仍东西！\n"}] = conn2.output
    end

    test "entries/0 暴露已配置条目（覆盖度统计）" do
      entries = MessageOnly.entries()
      assert {"hangzhou:liuzhuang", "knock"} in entries
      assert {"huanggong:inwell", "reach"} in entries
      assert {"chengdu:guangchang", "drink"} in entries
      assert {"register:prison", "drop"} in entries
    end
  end
end
