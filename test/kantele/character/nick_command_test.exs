defmodule Kantele.Character.NickCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.NickCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  defp player do
    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      meta: %PlayerMeta{
        vitals: Vitals.new(),
        stats: Stats.new(),
        combat: Kantele.Character.Combat.new()
      }
    }
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  describe "nick 设置与清除" do
    test "空参数提示" do
      conn = NickCommand.run(build_conn(player()), %{"rest" => ""})
      assert output_text(conn) =~ "什么绰号"
    end

    test "设置绰号更新 meta" do
      conn = NickCommand.run(build_conn(player()), %{"rest" => "玉面飞龙"})
      updated = conn.private.update_character || conn.character
      assert updated.meta.nickname == "玉面飞龙"
      assert output_text(conn) =~ "取好了绰号"
    end

    test "nick none 清除" do
      char = %{player() | meta: %{player().meta | nickname: "玉面飞龙"}}
      conn = NickCommand.run(build_conn(char), %{"rest" => "none"})
      updated = conn.private.update_character || conn.character
      assert updated.meta.nickname == nil
      assert output_text(conn) =~ "取消了"
    end

    test "超长拒绝" do
      long = String.duplicate("字", 40)
      conn = NickCommand.run(build_conn(player()), %{"rest" => long})
      assert output_text(conn) =~ "太长了"
    end
  end

  test "nick 路由解析" do
    {:ok, parsed} = Kantele.Character.Commands.parse("nick 玉面飞龙")
    assert parsed.module == Kantele.Character.NickCommand

    {:ok, parsed} = Kantele.Character.Commands.parse("昵称 玉面飞龙")
    assert parsed.module == Kantele.Character.NickCommand
  end
end
