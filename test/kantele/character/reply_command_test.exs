defmodule Kantele.Character.ReplyCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.ReplyCommand

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  defp player(reply_to \\ nil) do
    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: [],
      meta: %PlayerMeta{
        reply_to: reply_to,
        vitals: Kantele.Character.Vitals.new(),
        stats: Kantele.Character.Stats.new(),
        combat: Kantele.Character.Combat.new()
      }
    }
  end

  describe "reply 命令" do
    test "reply 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("reply 好的")
      assert parsed.module == Kantele.Character.ReplyCommand
      assert parsed.function == :run
      assert parsed.params["text"] == "好的"
    end

    test "无人密语过时给出提示，不崩溃" do
      conn = build_conn(player())

      conn = ReplyCommand.run(conn, %{"text" => "来了"})

      assert output_text(conn) =~ "你要回复谁呢"
      refute Enum.any?(conn.events, &(&1.topic == "tell/send"))
    end

    test "有 reply_to 时把内容发给最后密语你的人" do
      conn = build_conn(player("李四"))

      conn = ReplyCommand.run(conn, %{"text" => "来了"})

      assert %{topic: "tell/send", data: data} = List.last(conn.events)
      assert data.name == "李四"
      assert data.text == "来了"
    end
  end
end