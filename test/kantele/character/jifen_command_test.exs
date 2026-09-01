defmodule Kantele.Character.JifenCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.JifenCommand
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

  test "无积分时提示尚无积分" do
    conn = JifenCommand.run(build_conn(player()), %{})
    assert output_text(conn) =~ "尚无积分记录"
  end

  test "有积分时显示积分" do
    p = %{player() | meta: %{player().meta | jifen: 120}}
    conn = JifenCommand.run(build_conn(p), %{})
    assert output_text(conn) =~ "积分为120点"
  end

  test "jifen 路由解析" do
    {:ok, parsed} = Kantele.Character.Commands.parse("jifen")
    assert parsed.module == Kantele.Character.JifenCommand
  end
end