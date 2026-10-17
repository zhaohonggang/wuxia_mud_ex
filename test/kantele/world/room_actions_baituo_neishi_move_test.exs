defmodule Kantele.World.RoomActions.Baituo.Neishi.MoveTest do
  use ExUnit.Case, async: true

  alias Kalevala.Character
  alias Kalevala.Character.Conn
  alias Kalevala.Character.Conn.Private
  alias Kantele.World.RoomActions.Baituo.Neishi.Move

  @room "baituo:neishi"

  defp conn(family) do
    %Conn{
      character: %Character{name: "测试", room_id: @room, meta: %{family: %{born_family: family}}},
      private: %Private{channel_changes: []},
      output: []
    }
  end

  defp output_text(conn) do
    Enum.map(conn.output, fn
      %Conn.Text{data: data} -> data
      _ -> ""
    end)
  end

  defp published_text(conn) do
    case conn.private.channel_changes do
      [{:publish, _chan, event, _opts, _err} | _] -> event.data.text
      _ -> nil
    end
  end

  describe "run/2（开/关密道）" do
    test "arg 不是 pen → 只给本人提示，不广播、不改出口" do
      conn2 = Move.run(conn("欧阳世家"), %{verb: "move", trailing: "table", room_id: @room})

      assert Enum.any?(output_text(conn2), &String.contains?(&1, "你要搬什么"))
      assert conn2.private.channel_changes == []
    end

    test "门派不是欧阳世家 → 只给本人提示，不广播" do
      conn2 = Move.run(conn("其他门派"), %{verb: "move", trailing: "pen", room_id: @room})

      assert Enum.any?(output_text(conn2), &String.contains?(&1, "没发现什么特别的东西"))
      assert conn2.private.channel_changes == []
    end

    test "欧阳世家 + pen + 当前无 down 出口 → 广播开洞（set_exit 无进程时安全 no-op）" do
      conn2 = Move.run(conn("欧阳世家"), %{verb: "move", trailing: "pen", room_id: @room})

      text = published_text(conn2)
      assert is_binary(text)
      assert String.contains?(text, "露出一个黑幽幽的洞口")
      assert conn2.output == []
    end
  end
end
