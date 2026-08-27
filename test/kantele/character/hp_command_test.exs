defmodule Kantele.Character.HpCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.HpCommand

  defp player() do
    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      meta: %Kantele.Character.PlayerMeta{
        vitals: Kantele.Character.Vitals.new(),
        stats: Kantele.Character.Stats.new(),
        combat: Kantele.Character.Combat.new()
      }
    }
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      %Kalevala.Character.Conn.EventText{text: %Kalevala.Character.Conn.Text{data: data}} ->
        [IO.iodata_to_binary(data)]

      _ -> []
    end)
    |> Enum.join("")
  end

  describe "路由解析" do
    test "hp 解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("hp")
      assert parsed.function == :run
    end

    test "中文别名 气" do
      {:ok, parsed} = Kantele.Character.Commands.parse("气")
      assert parsed.function == :run
    end
  end

  describe "显示状态" do
    test "展示精气气血内力" do
      conn = HpCommand.run(build_conn(player()), %{})
      text = output_text(conn)

      assert text =~ "精气"
      assert text =~ "气血"
      assert text =~ "内力"
      assert text =~ "150/150"
    end
  end
end
